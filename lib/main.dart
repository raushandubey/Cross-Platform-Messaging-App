import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/colors.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try initializing Firebase
  try {
    // If running in your production environment, the Google configurations are parsed here
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isMockMode = false; // Successfully linked Firebase!
  } catch (e) {
    // Fall back gracefully to interactive Mock Mode if configurations are absent
    isMockMode = true;
    debugPrint('⚠️ Firebase not initialized: ${e.toString()}');
    debugPrint('ℹ️ Defaulting to interactive offline Pulse Mock Mode.');
  }



  // Initialize Notification Service
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('⚠️ Notification initialization failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, authProvider, chatProvider) {
            if (chatProvider != null) {
              if (authProvider.isAuthenticated) {
                chatProvider.setUserId(authProvider.user!.uid);
              } else {
                chatProvider.clear();
              }
            }
            return chatProvider ?? ChatProvider();
          },
        ),
      ],
      child: const PulseApp(),
    ),
  );
}

class PulseApp extends StatefulWidget {
  const PulseApp({super.key});

  @override
  State<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends State<PulseApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Request notification permissions after build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await NotificationService.instance.requestPermissions();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ==========================================
  // APP LIFECYCLE MONITOR (PRESENCE SYNC)
  // ==========================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 1. Sync global lifecycle string for notification suppression
    currentLifecycleState = state.name;

    // 2. Synchronize user active presence (online/offline status) in database
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      final uid = auth.user!.uid;
      if (state == AppLifecycleState.resumed) {
        // App opened -> Set Online
        DatabaseService.instance.updateOnlineStatus(uid, 'online');
      } else if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        // App closed/backgrounded -> Set Offline
        DatabaseService.instance.updateOnlineStatus(uid, 'offline');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulse Messaging',
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (auth.isLoading) {
            return _buildSplashLoader();
          }
          if (auth.isAuthenticated) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }

  Widget _buildSplashLoader() {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing blue circle loading indicator
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: AppColors.accentBlue,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Pulse',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
