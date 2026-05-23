import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'auth_service.dart';

abstract class DatabaseService {
  Stream<List<UserModel>> streamUsers();
  Stream<List<ChatModel>> streamChats(String uid);
  Stream<List<MessageModel>> streamMessages(String chatId);

  Future<void> sendMessage(
    String chatId,
    String senderId,
    String recipientId,
    String content,
  );
  Future<void> markChatAsRead(String chatId, String uid);
  Future<void> updateOnlineStatus(String uid, String status);
  Future<UserModel?> getUser(String uid);
  Future<ChatModel> getOrCreateChat(String uidA, String uidB);

  static DatabaseService get instance =>
      isMockMode ? MockDatabaseService() : FirebaseDatabaseService();
}

// ==========================================
// FIREBASE FIRESTORE DATABASE SERVICE
// ==========================================
class FirebaseDatabaseService implements DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<UserModel>> streamUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    });
  }

  @override
  Stream<List<ChatModel>> streamChats(String uid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs
              .map((doc) => ChatModel.fromMap(doc.data()))
              .toList();
          // Sort by last message timestamp descending
          chats.sort((a, b) {
            if (a.lastMessageTimestamp == null) return 1;
            if (b.lastMessageTimestamp == null) return -1;
            return b.lastMessageTimestamp!.compareTo(a.lastMessageTimestamp!);
          });
          return chats;
        });
  }

  @override
  Stream<List<MessageModel>> streamMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data()))
              .toList();
        });
  }

  @override
  Future<void> sendMessage(
    String chatId,
    String senderId,
    String recipientId,
    String content,
  ) async {
    if (content.trim().isEmpty) return;

    final messageId = const Uuid().v4();
    final now = DateTime.now();

    final message = MessageModel(
      id: messageId,
      senderId: senderId,
      recipientId: recipientId,
      content: content.trim(),
      timestamp: now,
      isRead: false,
    );

    // Using a Firestore Batch to guarantee atomic writes
    final batch = _firestore.batch();

    // 1. Add message
    final msgDoc = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    batch.set(msgDoc, message.toMap());

    // 2. Update Chat parent metadata
    final chatDoc = _firestore.collection('chats').doc(chatId);

    // Read and increment unread count inside a transaction/update
    batch.update(chatDoc, {
      'lastMessage': content.trim(),
      'lastMessageSenderId': senderId,
      'lastMessageTimestamp': Timestamp.fromDate(now),
      'unreadCounts.$recipientId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  @override
  Future<void> markChatAsRead(String chatId, String uid) async {
    final chatDoc = _firestore.collection('chats').doc(chatId);

    // Set unread count for current user to 0
    await chatDoc.update({'unreadCounts.$uid': 0});

    // Optionally mark all messages sent by the other user as read
    final unreadMessages = await chatDoc
        .collection('messages')
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadMessages.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  @override
  Future<void> updateOnlineStatus(String uid, String status) async {
    await _firestore.collection('users').doc(uid).update({
      'status': status,
      'lastSeen': Timestamp.now(),
    });
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Future<ChatModel> getOrCreateChat(String uidA, String uidB) async {
    // Standard alphanumeric sorted combination to prevent duplicate chats
    final participants = [uidA, uidB]..sort();
    final chatId = participants.join('_');

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();

    if (chatDoc.exists && chatDoc.data() != null) {
      return ChatModel.fromMap(chatDoc.data()!);
    }

    final newChat = ChatModel(
      id: chatId,
      participants: participants,
      unreadCounts: {uidA: 0, uidB: 0},
    );

    await _firestore.collection('chats').doc(chatId).set(newChat.toMap());
    return newChat;
  }
}

// ==========================================
// MOCK DATABASE SERVICE (For Offline Demo)
// ==========================================
class MockDatabaseService implements DatabaseService {
  // Singleton
  static final MockDatabaseService _singleton = MockDatabaseService._internal();
  factory MockDatabaseService() => _singleton;
  MockDatabaseService._internal() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _pollDatabaseUpdates();
    });
  }

  // Stream Controllers
  final StreamController<List<UserModel>> _usersStreamController =
      StreamController<List<UserModel>>.broadcast();
  final Map<String, StreamController<List<ChatModel>>> _chatsStreamControllers =
      {}; // uid -> stream
  final Map<String, StreamController<List<MessageModel>>>
  _messagesStreamControllers = {}; // chatId -> stream

  void _pollDatabaseUpdates() {
    // 1. Refresh active users stream
    if (_usersStreamController.hasListener) {
      _loadUsersFromPrefs();
    }
    // 2. Refresh active chats streams
    _chatsStreamControllers.forEach((uid, controller) {
      if (controller.hasListener) {
        _loadChatsFromPrefs(uid);
      }
    });
    // 3. Refresh active messages streams
    _messagesStreamControllers.forEach((chatId, controller) {
      if (controller.hasListener) {
        _loadMessagesFromPrefs(chatId);
      }
    });
  }

  /// Triggered after user login (left as a no-op to avoid crash since we load from SharedPreferences now)
  void seedInitialConversations(String currentUserUid) {
    _loadUsersFromPrefs();
  }

  void refreshUsers() {
    _loadUsersFromPrefs();
  }

  @override
  Stream<List<UserModel>> streamUsers() {
    _loadUsersFromPrefs();
    return _usersStreamController.stream;
  }

  Future<void> _loadUsersFromPrefs() async {
    try {
      final prefs = SharedPreferencesAsync();
      final listJson = await prefs.getString('pulse_mock_users_list') ?? '[]';
      final List<dynamic> listDecoded = jsonDecode(listJson);
      final list = listDecoded
          .map((m) => UserModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      _usersStreamController.add(list);
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  @override
  Stream<List<ChatModel>> streamChats(String uid) {
    if (!_chatsStreamControllers.containsKey(uid)) {
      _chatsStreamControllers[uid] =
          StreamController<List<ChatModel>>.broadcast();
    }
    _loadChatsFromPrefs(uid);
    return _chatsStreamControllers[uid]!.stream;
  }

  Future<void> _loadChatsFromPrefs(String uid) async {
    try {
      final prefs = SharedPreferencesAsync();
      final chatsJson = await prefs.getString('pulse_mock_chats') ?? '{}';
      final Map<String, dynamic> chatsMap = jsonDecode(chatsJson);
      final List<ChatModel> list = [];
      chatsMap.forEach((key, val) {
        final chat = ChatModel.fromMap(Map<String, dynamic>.from(val));
        if (chat.participants.contains(uid)) {
          list.add(chat);
        }
      });
      list.sort((a, b) {
        if (a.lastMessageTimestamp == null) return 1;
        if (b.lastMessageTimestamp == null) return -1;
        return b.lastMessageTimestamp!.compareTo(a.lastMessageTimestamp!);
      });
      if (_chatsStreamControllers.containsKey(uid)) {
        _chatsStreamControllers[uid]!.add(list);
      }
    } catch (e) {
      debugPrint('Error loading chats: $e');
    }
  }

  @override
  Stream<List<MessageModel>> streamMessages(String chatId) {
    if (!_messagesStreamControllers.containsKey(chatId)) {
      _messagesStreamControllers[chatId] =
          StreamController<List<MessageModel>>.broadcast();
    }
    _loadMessagesFromPrefs(chatId);
    return _messagesStreamControllers[chatId]!.stream;
  }

  Future<void> _loadMessagesFromPrefs(String chatId) async {
    try {
      final prefs = SharedPreferencesAsync();
      final msgsJson = await prefs.getString('pulse_mock_messages_$chatId') ?? '[]';
      final List<dynamic> listDecoded = jsonDecode(msgsJson);
      final list = listDecoded
          .map((m) => MessageModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (_messagesStreamControllers.containsKey(chatId)) {
        _messagesStreamControllers[chatId]!.add(list);
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  @override
  Future<void> sendMessage(
    String chatId,
    String senderId,
    String recipientId,
    String content,
  ) async {
    if (content.trim().isEmpty) return;

    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final newMessage = MessageModel(
      id: messageId,
      senderId: senderId,
      recipientId: recipientId,
      content: content.trim(),
      timestamp: now,
      isRead: false,
    );

    final prefs = SharedPreferencesAsync();

    // 1. Save Message to persistent list
    final msgsJson = await prefs.getString('pulse_mock_messages_$chatId') ?? '[]';
    final List<dynamic> listDecoded = jsonDecode(msgsJson);
    listDecoded.add({
      'id': newMessage.id,
      'senderId': newMessage.senderId,
      'recipientId': newMessage.recipientId,
      'content': newMessage.content,
      'timestamp': newMessage.timestamp.millisecondsSinceEpoch,
      'isRead': newMessage.isRead,
    });
    await prefs.setString(
      'pulse_mock_messages_$chatId',
      jsonEncode(listDecoded),
    );

    // 2. Update Chat parent metadata
    final chatsJson = await prefs.getString('pulse_mock_chats') ?? '{}';
    final Map<String, dynamic> chatsMap = jsonDecode(chatsJson);

    Map<String, dynamic> chatMap;
    if (chatsMap.containsKey(chatId)) {
      chatMap = Map<String, dynamic>.from(chatsMap[chatId]);
    } else {
      chatMap = {
        'id': chatId,
        'participants': [senderId, recipientId]..sort(),
        'unreadCounts': {senderId: 0, recipientId: 0},
      };
    }

    final rawUnreads = Map<String, dynamic>.from(chatMap['unreadCounts'] ?? {});
    final recipientCount = (rawUnreads[recipientId] as num? ?? 0).toInt();
    rawUnreads[recipientId] = recipientCount + 1;

    chatMap['lastMessage'] = content.trim();
    chatMap['lastMessageSenderId'] = senderId;
    chatMap['lastMessageTimestamp'] = now.millisecondsSinceEpoch;
    chatMap['unreadCounts'] = rawUnreads;

    chatsMap[chatId] = chatMap;
    await prefs.setString('pulse_mock_chats', jsonEncode(chatsMap));

    // 3. Notify listeners
    _loadChatsFromPrefs(senderId);
    _loadChatsFromPrefs(recipientId);
    _loadMessagesFromPrefs(chatId);
  }

  @override
  Future<void> markChatAsRead(String chatId, String uid) async {
    final prefs = SharedPreferencesAsync();
    final chatsJson = await prefs.getString('pulse_mock_chats') ?? '{}';
    final Map<String, dynamic> chatsMap = jsonDecode(chatsJson);

    if (chatsMap.containsKey(chatId)) {
      final chatMap = Map<String, dynamic>.from(chatsMap[chatId]);
      final rawUnreads = Map<String, dynamic>.from(
        chatMap['unreadCounts'] ?? {},
      );
      rawUnreads[uid] = 0;
      chatMap['unreadCounts'] = rawUnreads;
      chatsMap[chatId] = chatMap;
      await prefs.setString('pulse_mock_chats', jsonEncode(chatsMap));
      _loadChatsFromPrefs(uid);
    }

    // Mark messages as read
    final msgsJson = await prefs.getString('pulse_mock_messages_$chatId') ?? '[]';
    final List<dynamic> listDecoded = jsonDecode(msgsJson);
    bool modified = false;
    for (int i = 0; i < listDecoded.length; i++) {
      if (listDecoded[i]['recipientId'] == uid &&
          listDecoded[i]['isRead'] == false) {
        listDecoded[i]['isRead'] = true;
        modified = true;
      }
    }
    if (modified) {
      await prefs.setString(
        'pulse_mock_messages_$chatId',
        jsonEncode(listDecoded),
      );
      _loadMessagesFromPrefs(chatId);
    }
  }

  @override
  Future<void> updateOnlineStatus(String uid, String status) async {
    final prefs = SharedPreferencesAsync();
    final listJson = await prefs.getString('pulse_mock_users_list') ?? '[]';
    final List<dynamic> listDecoded = jsonDecode(listJson);
    for (int i = 0; i < listDecoded.length; i++) {
      if (listDecoded[i]['uid'] == uid) {
        listDecoded[i]['status'] = status;
        listDecoded[i]['lastSeen'] = DateTime.now().millisecondsSinceEpoch;
        break;
      }
    }
    await prefs.setString('pulse_mock_users_list', jsonEncode(listDecoded));
    _loadUsersFromPrefs();
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    final prefs = SharedPreferencesAsync();
    final listJson = await prefs.getString('pulse_mock_users_list') ?? '[]';
    final List<dynamic> listDecoded = jsonDecode(listJson);
    for (var m in listDecoded) {
      if (m['uid'] == uid) {
        return UserModel.fromMap(Map<String, dynamic>.from(m));
      }
    }
    return null;
  }

  @override
  Future<ChatModel> getOrCreateChat(String uidA, String uidB) async {
    final sorted = [uidA, uidB]..sort();
    final chatId = sorted.join('_');

    final prefs = SharedPreferencesAsync();
    final chatsJson = await prefs.getString('pulse_mock_chats') ?? '{}';
    final Map<String, dynamic> chatsMap = jsonDecode(chatsJson);

    if (chatsMap.containsKey(chatId)) {
      return ChatModel.fromMap(Map<String, dynamic>.from(chatsMap[chatId]));
    }

    final newChat = ChatModel(
      id: chatId,
      participants: sorted,
      unreadCounts: {uidA: 0, uidB: 0},
    );

    final jsonSafeMap = {
      'id': newChat.id,
      'participants': newChat.participants,
      'lastMessage': null,
      'lastMessageSenderId': null,
      'lastMessageTimestamp': null,
      'unreadCounts': newChat.unreadCounts,
    };
    chatsMap[chatId] = jsonSafeMap;
    await prefs.setString('pulse_mock_chats', jsonEncode(chatsMap));

    _loadChatsFromPrefs(uidA);
    return newChat;
  }
}
