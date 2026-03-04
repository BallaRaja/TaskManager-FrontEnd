// lib/main.dart
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/session_manager.dart';
import 'core/services/notification_service.dart'; // ← Local notification fallback
import 'core/services/fcm_service.dart'; // ← Real server-sent push notifications
import 'core/services/offline_sync_service.dart'; // ← Offline task queue + auto-sync
import 'package:client/features/auth/data/auth_api.dart';
import 'package:client/features/auth/presentation/login_page.dart';
import 'package:client/features/tasks/presentation/tasks_page.dart';
import 'package:client/features/tasks/presentation/tasks_controller.dart';
import 'package:client/features/calendar/presentation/calendar_page.dart';
import 'package:client/features/calendar/presentation/calendar_controller.dart';
import 'package:client/features/ai/presentation/ai_chat_page.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Initialize Firebase (required before using FCM)
  // Wrapped in try-catch — Firebase isn't available on Linux desktop
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('⚠️ Firebase init failed (expected on desktop): $e');
  }

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    // Initialize FCM service — real server-sent push notifications
    await FcmService.instance.init();

    // Keep local notifications as a fallback channel
    await NotificationService().init();
  } else {
    debugPrint("🖥️ Desktop/Web — skipping mobile notification initialization");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  late Future<Widget> _startPageFuture;

  @override
  void initState() {
    super.initState();
    _startPageFuture = _decideStartPage();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final isDark = await AppTheme.loadTheme();
    if (mounted) {
      setState(() {
        _isDarkMode = isDark;
      });
    }
  }

  Future<void> _onThemeChanged(bool isDarkMode) async {
    await AppTheme.saveTheme(isDarkMode);
    if (mounted) {
      setState(() {
        _isDarkMode = isDarkMode;
      });
    }
  }

  Future<Widget> _decideStartPage() async {
    final token = await SessionManager.getToken();
    final savedUserId = await SessionManager.getUserId();

    if (token == null || token.isEmpty) {
      debugPrint("No token found → Redirecting to Login");
      return LoginPage(onThemeChanged: _onThemeChanged);
    }

    try {
      final result = await AuthApi.verifySession(
        token,
      ).timeout(const Duration(seconds: 10));

      if (result != null && result["valid"] == true) {
        final userId = result["userId"].toString();

        // Save complete session
        await SessionManager.saveFullSession(
          token,
          await SessionManager.getEmail() ?? "",
          userId,
        );

        debugPrint("Valid session → Loading MainAppShell for user: $userId");

        // Register FCM token with backend so server can send real push notifications
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          await FcmService.instance.registerTokenWithBackend();
          await NotificationService().scheduleAllNotifications();
        }

        return MainAppShell(userId: userId, onThemeChanged: _onThemeChanged);
      }

      final unauthorized = result != null && result["unauthorized"] == true;
      if (unauthorized) {
        await SessionManager.clearSession();
        return LoginPage(onThemeChanged: _onThemeChanged);
      }
    } catch (e) {
      debugPrint("Session verification failed: $e");

      if (savedUserId != null && savedUserId.isNotEmpty) {
        debugPrint(
          "Using cached session after verify failure for user: $savedUserId",
        );
        // Still register FCM token for offline-resumed sessions
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          await FcmService.instance.registerTokenWithBackend();
        }
        return MainAppShell(
          userId: savedUserId,
          onThemeChanged: _onThemeChanged,
        );
      }
    }

    if (savedUserId != null && savedUserId.isNotEmpty) {
      debugPrint(
        "Verify unavailable → keeping cached session for user: $savedUserId",
      );
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await FcmService.instance.registerTokenWithBackend();
      }
      return MainAppShell(userId: savedUserId, onThemeChanged: _onThemeChanged);
    }

    await SessionManager.clearSession();
    return LoginPage(onThemeChanged: _onThemeChanged);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Manager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: FutureBuilder<Widget>(
        future: _startPageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return snapshot.data!;
          }

          // Fallback error screen
          return const Scaffold(
            body: Center(
              child: Text(
                "Failed to load app. Please restart.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}

class MainAppShell extends StatefulWidget {
  final String userId;
  final ValueChanged<bool> onThemeChanged;

  const MainAppShell({
    super.key,
    required this.userId,
    required this.onThemeChanged,
  });

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _selectedIndex = 0; // Start on Tasks tab
  final OfflineSyncService _offlineSync = OfflineSyncService();

  late final List<Widget> _pages = [
    TasksPage(onThemeChanged: widget.onThemeChanged),
    const AIChatPage(),
    CalendarPage(onThemeChanged: widget.onThemeChanged),
  ];

  @override
  void dispose() {
    _offlineSync.removeListener(_onSyncChanged);
    _offlineSync.dispose_();
    super.dispose();
  }

  void _onSyncChanged() {
    if (mounted) setState(() {});
  }

  /// Called once after the first build, when Provider is available.
  void _initOfflineSync(BuildContext ctx) {
    final tasksCtrl = Provider.of<TasksController>(ctx, listen: false);
    final calCtrl = Provider.of<CalendarController>(ctx, listen: false);

    _offlineSync.onTaskSynced = (tempId, serverTask) {
      tasksCtrl.replaceTempTask(tempId, serverTask);
      calCtrl.upsertTaskLocal(serverTask);
    };

    _offlineSync.onSyncComplete = () {
      // Full refresh to reconcile any ordering / counts
      tasksCtrl.refresh();
      calCtrl.refresh();
    };

    _offlineSync.addListener(_onSyncChanged);
    _offlineSync.init();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Refresh notifications when switching to relevant tabs
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      if (index == 0 || index == 2) {
        NotificationService().scheduleAllNotifications();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TasksController()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => CalendarController()..init(),
        ),
      ],
      child: Builder(
        builder: (innerCtx) {
          // One-time wiring after providers are available
          if (_offlineSync.onTaskSynced == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initOfflineSync(innerCtx);
            });
          }

          return Scaffold(
            body: Column(
              children: [
                // ── Offline / syncing banner ──
                if (!_offlineSync.isOnline || _offlineSync.isSyncing)
                  _OfflineBanner(
                    isOnline: _offlineSync.isOnline,
                    isSyncing: _offlineSync.isSyncing,
                    pendingCount: _offlineSync.pendingCount,
                  ),
                Expanded(
                  child: IndexedStack(
                      index: _selectedIndex, children: _pages),
                ),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.checklist),
                  label: 'Tasks',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.auto_awesome),
                  label: 'AI',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today),
                  label: 'Calendar',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A small banner shown at the top when the device is offline or syncing.
class _OfflineBanner extends StatelessWidget {
  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;

  const _OfflineBanner({
    required this.isOnline,
    required this.isSyncing,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String text;
    final IconData icon;

    if (isSyncing) {
      bg = Colors.blue;
      text = 'Syncing $pendingCount task${pendingCount == 1 ? '' : 's'}…';
      icon = Icons.sync_rounded;
    } else {
      bg = Colors.orange;
      text = pendingCount > 0
          ? 'You\'re offline · $pendingCount task${pendingCount == 1 ? '' : 's'} pending'
          : 'You\'re offline';
      icon = Icons.cloud_off_rounded;
    }

    return Material(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isSyncing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
