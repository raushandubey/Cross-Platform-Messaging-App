import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<UserModel?>? _authSubscription;

  AuthProvider() {
    _init();
  }

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _init() {
    _isLoading = true;
    notifyListeners();

    // Safety timeout: if the stream hasn't responded in 3 seconds,
    // stop loading and show login screen (prevents infinite splash)
    Future.delayed(const Duration(seconds: 3), () {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    });

    _authSubscription = _authService.onAuthStateChanged.listen(
      (UserModel? loggedUser) {
        _user = loggedUser;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();

        if (loggedUser != null) {
          // Sync FCM token
          NotificationService.instance.updateTokenInFirestore(loggedUser.uid);

          // Seed initial conversations if running in Mock Mode
          if (isMockMode) {
            final mockDb = DatabaseService.instance as MockDatabaseService;
            mockDb.seedInitialConversations(loggedUser.uid);
          }
        }
      },
      onError: (err) {
        _user = null;
        _isLoading = false;
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _clearError();
    try {
      _user = await _authService.signInWithEmailAndPassword(email, password);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    _setLoading(true);
    _clearError();
    try {
      _user = await _authService.signUpWithEmailAndPassword(
        name,
        email,
        password,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _user = null;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile(String displayName, String status) async {
    if (_user == null) return false;
    _setLoading(true);
    _clearError();
    try {
      final updated = await _authService.updateProfile(_user!.uid, displayName, status);
      _user = updated;
      _setLoading(false);
      if (isMockMode) {
        final mockDb = DatabaseService.instance as MockDatabaseService;
        mockDb.refreshUsers();
      }
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.resetPassword(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setError(String msg) {
    debugPrint('❌ [AUTH_PROVIDER] Error encountered: $msg');

    if (msg.contains('invalid-email')) {
      _errorMessage = 'Please enter a valid email address.';
    } else if (msg.contains('user-not-found') ||
        msg.contains('wrong-password') ||
        msg.contains('invalid-credential')) {
      _errorMessage = 'Incorrect email or password.';
    } else if (msg.contains('email-already-in-use')) {
      _errorMessage = 'This email is already registered.';
    } else if (msg.contains('weak-password')) {
      _errorMessage = 'Password must be at least 6 characters.';
    } else if (msg.contains('operation-not-allowed')) {
      _errorMessage = 'Email/Password sign-in is disabled in Firebase. Please enable it in Firebase Console > Build > Authentication > Sign-in method.';
    } else if (msg.contains('api-key-not-valid')) {
      _errorMessage = 'Your Firebase API Key is invalid. Please check your firebase_options.dart configuration.';
    } else {
      final clean = msg.replaceAll(RegExp(r'\[.*\]'), '').trim();
      _errorMessage = clean.isEmpty || clean == 'Error' ? msg : clean;
    }
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
