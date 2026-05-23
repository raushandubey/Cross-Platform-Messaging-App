import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

// Global notification tracker variables
String? currentOpenChatId;
String currentLifecycleState = 'resumed'; // 'resumed' | 'paused' | 'inactive'

/// Global background message handler for FCM (Must be a top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('FCM background message received: ${message.messageId}');
  }
}

abstract class NotificationService {
  Future<void> initialize();
  Future<void> requestPermissions();
  Future<String?> getToken();
  Future<void> updateTokenInFirestore(String uid);

  // Deep linking select channel
  Stream<String> get onNotificationSelected;
  void triggerNotificationSelect(String chatId);

  // Testing local triggers
  void showMockLocalNotification({
    required String title,
    required String body,
    required String chatId,
  });

  static NotificationService get instance =>
      isMockMode ? MockNotificationService() : FirebaseNotificationService();
}

// ==========================================
// FIREBASE CLOUD MESSAGING NOTIFICATION SERVICE
// ==========================================
class FirebaseNotificationService implements NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> _onNotificationSelectedController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get onNotificationSelected =>
      _onNotificationSelectedController.stream;

  @override
  void triggerNotificationSelect(String chatId) {
    _onNotificationSelectedController.add(chatId);
  }

  @override
  Future<void> initialize() async {
    // 1. Initialize local notifications (Only on native mobile platforms)
    if (!kIsWeb) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            triggerNotificationSelect(payload);
          }
        },
      );

      // Create Android high-importance channel
      const channel = AndroidNotificationChannel(
        'pulse_high_importance',
        'Pulse Conversations',
        description: 'Notifications for active Pulse messages.',
        importance: Importance.max,
      );

      final platform = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (platform != null) {
        await platform.createNotificationChannel(channel);
      }
    }

    // 2. Set up FCM Background Message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. Set up FCM Foreground Message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final chatId = message.data['chatId'] ?? '';

      // WhatsApp Suppression Rule:
      // If the app is active AND the current open chat is the sender's chat, DO NOT show notification.
      if (currentLifecycleState == 'resumed' && currentOpenChatId == chatId) {
        if (kDebugMode) {
          print(
            'FCM Message suppressed: User is actively viewing chat $chatId',
          );
        }
        return;
      }

      // Otherwise show notification
      _showForegroundLocalNotification(message);
    });

    // 4. Set up FCM Message Opened App handler (Case 3 deep linking from system tray click)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final chatId = message.data['chatId'];
      if (chatId != null && chatId.isNotEmpty) {
        triggerNotificationSelect(chatId);
      }
    });

    // 5. Check if app was opened from terminated state via notification click
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      final chatId = initialMessage.data['chatId'];
      if (chatId != null && chatId.isNotEmpty) {
        // Yield after app builds
        Future.delayed(const Duration(milliseconds: 1200), () {
          triggerNotificationSelect(chatId);
        });
      }
    }
  }

  @override
  Future<void> requestPermissions() async {
    // Request FCM permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Request iOS Local Notification permission explicitly
    if (!kIsWeb) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        // FCM Web Push Credentials require a VAPID key
        // return await _fcm.getToken(vapidKey: 'YOUR_VAPID_KEY');
        return await _fcm.getToken();
      }
      return await _fcm.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateTokenInFirestore(String uid) async {
    try {
      final token = await getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': token,
        });
      }
    } catch (_) {}
  }

  Future<void> _showForegroundLocalNotification(RemoteMessage message) async {
    if (kIsWeb) return; // Browser notifications handled natively or custom UI

    final title = message.notification?.title ?? 'Pulse';
    final body = message.notification?.body ?? 'New message';
    final chatId = message.data['chatId'] ?? '';

    const androidDetails = AndroidNotificationDetails(
      'pulse_high_importance',
      'Pulse Conversations',
      channelDescription: 'Notifications for active Pulse messages.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: chatId,
    );
  }

  @override
  void showMockLocalNotification({
    required String title,
    required String body,
    required String chatId,
  }) {
    // No-op in production firebase mode unless manually routed
  }
}

// ==========================================
// MOCK NOTIFICATION SERVICE (For Offline Demo)
// ==========================================
class MockNotificationService implements NotificationService {
  // Singleton
  static final MockNotificationService _singleton =
      MockNotificationService._internal();
  factory MockNotificationService() => _singleton;
  MockNotificationService._internal() {
    _initLocalMockNotification();
  }

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _onNotificationSelectedController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get onNotificationSelected =>
      _onNotificationSelectedController.stream;

  @override
  void triggerNotificationSelect(String chatId) {
    _onNotificationSelectedController.add(chatId);
  }

  Future<void> _initLocalMockNotification() async {
    if (!kIsWeb) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      try {
        await _localNotifications.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            final payload = response.payload;
            if (payload != null && payload.isNotEmpty) {
              triggerNotificationSelect(payload);
            }
          },
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> initialize() async {
    if (kDebugMode) {
      print('Mock Notification Service Initialized.');
    }
  }

  @override
  Future<void> requestPermissions() async {
    if (kDebugMode) {
      print('Mock Notification permissions granted.');
    }
  }

  @override
  Future<String?> getToken() async => 'mock_fcm_token_xyz_12345';

  @override
  Future<void> updateTokenInFirestore(String uid) async {
    if (kDebugMode) {
      print('Mock FCM Token updated in Firestore for user $uid');
    }
  }

  @override
  void showMockLocalNotification({
    required String title,
    required String body,
    required String chatId,
  }) async {
    // WhatsApp Suppression Rule:
    // If the app is active AND the current open chat is the sender's chat, DO NOT show notification.
    if (currentLifecycleState == 'resumed' && currentOpenChatId == chatId) {
      return;
    }

    if (kIsWeb) {
      // For web, print in log or trigger deep link in console (we can also do standard browser notification)
      if (kDebugMode) {
        print('🔔 [MOCK WEB NOTIFICATION] $title: $body (Payload: $chatId)');
      }
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'pulse_high_importance',
      'Pulse Conversations',
      channelDescription: 'Notifications for active Pulse messages.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        id: chatId.hashCode + DateTime.now().millisecond,
        title: title,
        body: body,
        notificationDetails: details,
        payload: chatId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('🔔 [FALLBACK NOTIFICATION] $title: $body (Payload: $chatId)');
      }
    }
  }
}
