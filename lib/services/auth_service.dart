import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as f_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Central flag to toggle mock vs Firebase mode.
/// Updated during initialization in main.dart.
bool isMockMode = true;

abstract class AuthService {
  Stream<UserModel?> get onAuthStateChanged;
  UserModel? get currentUser;

  Future<UserModel> signInWithEmailAndPassword(String email, String password);
  Future<UserModel> signUpWithEmailAndPassword(
    String name,
    String email,
    String password,
  );
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<UserModel> updateProfile(String uid, String displayName, String status);

  static AuthService get instance =>
      isMockMode ? MockAuthService() : FirebaseAuthService();
}

// ==========================================
// FIREBASE AUTHENTICATION SERVICE
// ==========================================
class FirebaseAuthService implements AuthService {
  final f_auth.FirebaseAuth _auth = f_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache current logged in user model
  UserModel? _currentUserCached;

  @override
  UserModel? get currentUser => _currentUserCached;

  @override
  Stream<UserModel?> get onAuthStateChanged {
    return _auth.authStateChanges().asyncMap((fUser) async {
      if (fUser == null) {
        _currentUserCached = null;
        return null;
      }
      try {
        final doc = await _firestore.collection('users').doc(fUser.uid).get();
        if (doc.exists && doc.data() != null) {
          _currentUserCached = UserModel.fromMap(doc.data()!);
          return _currentUserCached;
        }
        // Fallback if auth exists but firestore doc is delayed
        final fallback = UserModel(
          uid: fUser.uid,
          email: fUser.email ?? '',
          displayName: fUser.displayName ?? 'Pulse User',
          lastSeen: DateTime.now(),
          status: 'online',
        );
        _currentUserCached = fallback;
        return fallback;
      } catch (_) {
        final fallback = UserModel(
          uid: fUser.uid,
          email: fUser.email ?? '',
          displayName: fUser.displayName ?? 'Pulse User',
          lastSeen: DateTime.now(),
          status: 'online',
        );
        _currentUserCached = fallback;
        return fallback;
      }
    });
  }

  @override
  Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user == null) {
      throw Exception('Failed to sign in. User is null.');
    }

    final doc = await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .get();
    if (!doc.exists) {
      // Create user record if missing in firestore
      final user = UserModel(
        uid: credential.user!.uid,
        email: email.trim(),
        displayName: credential.user!.displayName ?? 'Pulse User',
        status: 'online',
        lastSeen: DateTime.now(),
      );
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
      _currentUserCached = user;
      return user;
    }

    // Update status to online
    await _firestore.collection('users').doc(credential.user!.uid).update({
      'status': 'online',
      'lastSeen': Timestamp.now(),
    });

    final loggedUser = UserModel.fromMap(doc.data()!);
    _currentUserCached = loggedUser;
    return loggedUser;
  }

  @override
  Future<UserModel> signUpWithEmailAndPassword(
    String name,
    String email,
    String password,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user == null) {
      throw Exception('Failed to register. User is null.');
    }

    // Update Firebase Auth profile
    await credential.user!.updateDisplayName(name.trim());

    // Create Firestore User
    final newUser = UserModel(
      uid: credential.user!.uid,
      email: email.trim(),
      displayName: name.trim(),
      status: 'online',
      lastSeen: DateTime.now(),
    );

    await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
    _currentUserCached = newUser;
    return newUser;
  }

  @override
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _firestore.collection('users').doc(uid).update({
          'status': 'offline',
          'lastSeen': Timestamp.now(),
        });
      } catch (_) {}
    }
    await _auth.signOut();
    _currentUserCached = null;
  }

  @override
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<UserModel> updateProfile(
    String uid,
    String displayName,
    String status,
  ) async {
    await _firestore.collection('users').doc(uid).update({
      'displayName': displayName.trim(),
      'status': status,
    });
    if (_currentUserCached != null && _currentUserCached!.uid == uid) {
      _currentUserCached = _currentUserCached!.copyWith(
        displayName: displayName.trim(),
        status: status,
      );
    }
    return _currentUserCached ??
        UserModel(
          uid: uid,
          email: _auth.currentUser?.email ?? '',
          displayName: displayName.trim(),
          status: status,
          lastSeen: DateTime.now(),
        );
  }
}

// ==========================================
// MOCK AUTHENTICATION SERVICE (For Offline Demo)
// ==========================================
class MockAuthService implements AuthService {
  // Singleton
  static final MockAuthService _singleton = MockAuthService._internal();
  factory MockAuthService() => _singleton;
  MockAuthService._internal() {
    _loadPersistedUser();
  }

  final StreamController<UserModel?> _authStreamController =
      StreamController<UserModel?>.broadcast();
  UserModel? _mockCurrentUser;

  Future<void> _loadPersistedUser() async {
    try {
      final prefs = SharedPreferencesAsync();
      final userJson = await prefs.getString('pulse_mock_current_user');
      if (userJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(userJson);
        final user = UserModel.fromMap(decoded);
        _mockCurrentUser = user;
        _authStreamController.add(user);
      } else {
        _authStreamController.add(null);
      }
    } catch (e) {
      debugPrint('Error loading persisted user: $e');
      _authStreamController.add(null);
    }
  }

  @override
  UserModel? get currentUser => _mockCurrentUser;

  @override
  Stream<UserModel?> get onAuthStateChanged {
    Future.microtask(() {
      if (!_authStreamController.isClosed) {
        _authStreamController.add(_mockCurrentUser);
      }
    });
    return _authStreamController.stream;
  }

  @override
  Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (!email.contains('@') || password.length < 6) {
      throw Exception('Invalid credentials. Password must be at least 6 characters.');
    }

    final prefs = SharedPreferencesAsync();
    final usersJson = await prefs.getString('pulse_mock_users_map') ?? '{}';
    final Map<String, dynamic> usersMap = jsonDecode(usersJson);

    final normalizedEmail = email.trim().toLowerCase();
    if (!usersMap.containsKey(normalizedEmail)) {
      throw Exception('Incorrect email or password.');
    }

    final Map<String, dynamic> userData = usersMap[normalizedEmail];
    final String storedPassword = userData['password'];
    if (storedPassword != password) {
      throw Exception('Incorrect email or password.');
    }

    final loggedUser = UserModel.fromMap(Map<String, dynamic>.from(userData['user'])).copyWith(
      status: 'online',
      lastSeen: DateTime.now(),
    );

    // Update status in users map
    userData['user'] = loggedUser.toJsonMap();
    await prefs.setString('pulse_mock_users_map', jsonEncode(usersMap));

    // Update status in users list
    final listJson = await prefs.getString('pulse_mock_users_list') ?? '[]';
    final List<dynamic> listDecoded = jsonDecode(listJson);
    for (int i = 0; i < listDecoded.length; i++) {
      if (listDecoded[i]['uid'] == loggedUser.uid) {
        listDecoded[i] = loggedUser.toJsonMap();
        break;
      }
    }
    await prefs.setString('pulse_mock_users_list', jsonEncode(listDecoded));

    // Persist current session
    _mockCurrentUser = loggedUser;
    await prefs.setString('pulse_mock_current_user', jsonEncode(loggedUser.toJsonMap()));
    _authStreamController.add(loggedUser);

    return loggedUser;
  }

  @override
  Future<UserModel> signUpWithEmailAndPassword(
    String name,
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (name.isEmpty) throw Exception('Name cannot be empty.');
    if (!email.contains('@')) throw Exception('Invalid email format.');
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final prefs = SharedPreferencesAsync();
    
    // Load registered users map
    final usersJson = await prefs.getString('pulse_mock_users_map') ?? '{}';
    final Map<String, dynamic> usersMap = jsonDecode(usersJson);

    final normalizedEmail = email.trim().toLowerCase();
    if (usersMap.containsKey(normalizedEmail)) {
      throw Exception('This email is already registered.');
    }

    final newUser = UserModel(
      uid: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      email: email.trim(),
      displayName: name.trim(),
      status: 'online',
      lastSeen: DateTime.now(),
    );

    // Save to users map
    usersMap[normalizedEmail] = {
      'user': newUser.toJsonMap(),
      'password': password,
    };
    await prefs.setString('pulse_mock_users_map', jsonEncode(usersMap));

    // Save to user list
    final listJson = await prefs.getString('pulse_mock_users_list') ?? '[]';
    final List<dynamic> listDecoded = jsonDecode(listJson);
    listDecoded.add(newUser.toJsonMap());
    await prefs.setString('pulse_mock_users_list', jsonEncode(listDecoded));

    // Persist current session
    _mockCurrentUser = newUser;
    await prefs.setString('pulse_mock_current_user', jsonEncode(newUser.toJsonMap()));
    _authStreamController.add(newUser);

    return newUser;
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final currentUser = _mockCurrentUser;
    if (currentUser != null) {
      final prefs = SharedPreferencesAsync();
      
      // Update online status in all places
      final normalizedEmail = currentUser.email.toLowerCase();
      final usersJson = await prefs.getString('pulse_mock_users_map') ?? '{}';
      final Map<String, dynamic> usersMap = jsonDecode(usersJson);
      if (usersMap.containsKey(normalizedEmail)) {
        usersMap[normalizedEmail]['user']['status'] = 'offline';
        usersMap[normalizedEmail]['user']['lastSeen'] = DateTime.now().millisecondsSinceEpoch;
        await prefs.setString('pulse_mock_users_map', jsonEncode(usersMap));
      }

      final listJson = await prefs.getString('pulse_mock_users_list') ?? '[]';
      final List<dynamic> listDecoded = jsonDecode(listJson);
      for (int i = 0; i < listDecoded.length; i++) {
        if (listDecoded[i]['uid'] == currentUser.uid) {
          listDecoded[i]['status'] = 'offline';
          listDecoded[i]['lastSeen'] = DateTime.now().millisecondsSinceEpoch;
          break;
        }
      }
      await prefs.setString('pulse_mock_users_list', jsonEncode(listDecoded));
      
      await prefs.remove('pulse_mock_current_user');
    }
    _mockCurrentUser = null;
    _authStreamController.add(null);
  }

  @override
  Future<void> resetPassword(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!email.contains('@')) throw Exception('Invalid email.');
  }

  @override
  Future<UserModel> updateProfile(
    String uid,
    String displayName,
    String status,
  ) async {
    final prefs = SharedPreferencesAsync();
    
    // Update users list
    final listJson = await prefs.getString('pulse_mock_users_list') ?? '[]';
    final List<dynamic> listDecoded = jsonDecode(listJson);
    UserModel? updatedUser;

    for (int i = 0; i < listDecoded.length; i++) {
      if (listDecoded[i]['uid'] == uid) {
        listDecoded[i]['displayName'] = displayName.trim();
        listDecoded[i]['status'] = status;
        updatedUser = UserModel.fromMap(Map<String, dynamic>.from(listDecoded[i]));
        break;
      }
    }
    if (updatedUser == null) {
      throw Exception('User not found.');
    }
    await prefs.setString('pulse_mock_users_list', jsonEncode(listDecoded));

    // Update users map
    final normalizedEmail = updatedUser.email.toLowerCase();
    final usersJson = await prefs.getString('pulse_mock_users_map') ?? '{}';
    final Map<String, dynamic> usersMap = jsonDecode(usersJson);
    if (usersMap.containsKey(normalizedEmail)) {
      usersMap[normalizedEmail]['user'] = updatedUser.toJsonMap();
      await prefs.setString('pulse_mock_users_map', jsonEncode(usersMap));
    }

    // Update current session
    if (_mockCurrentUser != null && _mockCurrentUser!.uid == uid) {
      _mockCurrentUser = updatedUser;
      await prefs.setString('pulse_mock_current_user', jsonEncode(updatedUser.toJsonMap()));
      _authStreamController.add(updatedUser);
    }

    return updatedUser;
  }

  /// Helper to force feed an authenticated mock user directly (used for diagnostics or fast logins)
  void forceLogin(UserModel user) {
    _mockCurrentUser = user;
    _authStreamController.add(user);
  }
}
