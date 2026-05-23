import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class ChatProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService.instance;

  String? _currentUserId;

  // Raw streams data
  List<UserModel> _users = [];
  List<ChatModel> _chats = [];
  List<MessageModel> _messages = [];

  // UI state
  String _searchQuery = '';
  ChatModel? _selectedChat;
  UserModel? _selectedChatRecipient;
  bool _isLoadingChats = false;
  bool _isLoadingMessages = false;

  // Stream Subscriptions
  StreamSubscription<List<UserModel>>? _usersSubscription;
  StreamSubscription<List<ChatModel>>? _chatsSubscription;
  StreamSubscription<List<MessageModel>>? _messagesSubscription;
  StreamSubscription<String>? _notificationSubscription;

  ChatProvider() {
    _listenToDeepLinks();
  }

  // Getters
  List<UserModel> get users => _users;
  List<ChatModel> get chats => _chats;
  List<MessageModel> get messages => _messages;
  String get searchQuery => _searchQuery;
  ChatModel? get selectedChat => _selectedChat;
  UserModel? get selectedChatRecipient => _selectedChatRecipient;
  bool get isLoadingChats => _isLoadingChats;
  bool get isLoadingMessages => _isLoadingMessages;

  /// Call this when user logs in to set up database listeners
  void setUserId(String uid) {
    debugPrint('👤 [CHAT_PROVIDER] setUserId: $uid');
    if (_currentUserId == uid) return;
    _currentUserId = uid;
    _cancelAllSubscriptions();

    _isLoadingChats = true;
    notifyListeners();

    // 1. Stream all users
    _usersSubscription = _dbService.streamUsers().listen((list) {
      debugPrint('👥 [CHAT_PROVIDER] Streamed ${list.length} users, currentUserId: $_currentUserId');
      _users = list.where((u) => u.uid != _currentUserId).toList();
      _updateSelectedRecipientDetails();
      notifyListeners();
    });

    // 2. Stream user's active chats
    _chatsSubscription = _dbService.streamChats(_currentUserId!).listen((list) {
      _chats = list;
      _isLoadingChats = false;

      // If we have a selected chat, sync it with the fresh data from stream
      if (_selectedChat != null) {
        final synced = list.where((c) => c.id == _selectedChat!.id);
        if (synced.isNotEmpty) {
          _selectedChat = synced.first;
        }
      }
      notifyListeners();
    });
  }

  /// Reset provider state on logout
  void clear() {
    _currentUserId = null;
    _selectedChat = null;
    _selectedChatRecipient = null;
    _users = [];
    _chats = [];
    _messages = [];
    _searchQuery = '';
    currentOpenChatId = null; // Reset suppression tracker
    _cancelAllSubscriptions();
    _listenToDeepLinks(); // re-listen for potential cold launch
    notifyListeners();
  }

  /// Listen for push notification click events to trigger deep linking
  void _listenToDeepLinks() {
    _notificationSubscription?.cancel();
    _notificationSubscription = NotificationService
        .instance
        .onNotificationSelected
        .listen((chatId) async {
          if (_currentUserId == null) {
            return; // Ignore if user is not authenticated yet
          }

          // Extract other participant UID from chatId ("uidA_uidB")
          final parts = chatId.split('_');
          final otherUid = parts.firstWhere(
            (id) => id != _currentUserId,
            orElse: () => '',
          );
          if (otherUid.isEmpty) return;

          // Select and open the chat
          await selectChatByRecipientUid(otherUid);
        });
  }

  /// Return user profile based on UID
  UserModel? getUserProfile(String uid) {
    final matches = _users.where((u) => u.uid == uid);
    if (matches.isNotEmpty) return matches.first;
    return null;
  }

  /// Sync details of selected recipient in case of status updates (online/offline)
  void _updateSelectedRecipientDetails() {
    if (_selectedChatRecipient != null) {
      final freshProfile = getUserProfile(_selectedChatRecipient!.uid);
      if (freshProfile != null) {
        _selectedChatRecipient = freshProfile;
      }
    }
  }

  /// Handle conversation search text
  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  /// Get chats matching search query
  List<ChatModel> getFilteredChats() {
    if (_searchQuery.isEmpty) return _chats;
    return _chats.where((chat) {
      final otherUid = chat.participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );
      final otherUser = getUserProfile(otherUid);
      if (otherUser == null) return false;
      return otherUser.displayName.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  /// Get other users (for new chat list) matching query
  List<UserModel> getFilteredUsers() {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((u) {
      return u.displayName.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  /// Main action when clicking a chat room or contact
  Future<void> selectChat(ChatModel chat) async {
    _selectedChat = chat;
    currentOpenChatId =
        chat.id; // Suppress foreground notifications for this room!

    // Find other participant user model
    final otherUid = chat.participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );
    _selectedChatRecipient = getUserProfile(otherUid);

    // Fallback if recipient profile isn't fetched yet in stream
    if (_selectedChatRecipient == null && otherUid.isNotEmpty) {
      _selectedChatRecipient = await _dbService.getUser(otherUid);
    }

    _isLoadingMessages = true;
    notifyListeners();

    // Reset unread count immediately in UI/Database
    await _dbService.markChatAsRead(chat.id, _currentUserId!);

    // Subscribe to messages stream
    _messagesSubscription?.cancel();
    _messagesSubscription = _dbService.streamMessages(chat.id).listen((list) {
      _messages = list;
      _isLoadingMessages = false;
      notifyListeners();
    });
  }

  /// Selects or creates a conversation based on the recipient's UID (Used in deep links / new chats)
  Future<void> selectChatByRecipientUid(String otherUid) async {
    if (_currentUserId == null) return;

    _isLoadingMessages = true;
    notifyListeners();

    final chat = await _dbService.getOrCreateChat(_currentUserId!, otherUid);
    await selectChat(chat);
  }

  /// Deselects conversation when navigating back in mobile layout
  void deselectChat() {
    _selectedChat = null;
    _selectedChatRecipient = null;
    _messages = [];
    currentOpenChatId = null; // Re-enable notifications
    _messagesSubscription?.cancel();
    notifyListeners();
  }

  /// Send message in active chat room
  Future<void> sendTextMessage(String content) async {
    if (_selectedChat == null ||
        _currentUserId == null ||
        _selectedChatRecipient == null) {
      return;
    }
    final chatId = _selectedChat!.id;
    final senderId = _currentUserId!;
    final recipientId = _selectedChatRecipient!.uid;

    await _dbService.sendMessage(chatId, senderId, recipientId, content);
  }

  void _cancelAllSubscriptions() {
    _usersSubscription?.cancel();
    _chatsSubscription?.cancel();
    _messagesSubscription?.cancel();
  }

  @override
  void dispose() {
    _cancelAllSubscriptions();
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
