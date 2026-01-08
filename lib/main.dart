// lib/main.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/session_manager.dart';
import 'core/services/notification_service.dart'; // ← Notification Service
import 'features/auth/data/auth_api.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/tasks/presentation/tasks_page.dart';
import 'features/ai/presentation/ai_chat_page.dart';
import 'features/calendar/presentation/calendar_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications ONLY on Android/iOS (flutter_native_timezone doesn't work on desktop/web)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await NotificationService().init();
  } else {
    debugPrint(
      "🖥️ Desktop/Web platform detected — skipping notification initialization",
    );
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

  @override
  void initState() {
    super.initState();
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

  Future<Widget> _decideStartPage() async {
    final token = await SessionManager.getToken();

    if (token == null || token.isEmpty) {
      debugPrint("No token found → Redirecting to Login");
      return const LoginPage();
    }

    try {
      final result = await AuthApi.verifySession(
        token,
      ).timeout(const Duration(seconds: 10));

      if (result != null && result["valid"] == true) {
        final userId = result["userId"] as String;

        // Save complete session
        await SessionManager.saveFullSession(
          token,
          await SessionManager.getEmail() ?? "",
          userId,
        );

        debugPrint("Valid session → Loading MainAppShell for user: $userId");

        // Schedule notifications only on mobile after successful login
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          await NotificationService().scheduleAllNotifications();
        }

        return MainAppShell(userId: userId);
      }
    } catch (e) {
      debugPrint("Session verification failed: $e");
    }

    // Invalid or expired token → clear and go to login
    await SessionManager.clearSession();
    return const LoginPage();
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
        future: _decideStartPage(),
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

  const MainAppShell({super.key, required this.userId});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _selectedIndex = 0; // Start on Tasks tab

  final List<Widget> _pages = const [TasksPage(), AIChatPage(), CalendarPage()];

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
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'AI'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}
