import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/session_manager.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/tasks/presentation/tasks_page.dart';
import 'features/ai/presentation/ai_chat_page.dart';
import 'features/calendar/presentation/calendar_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    print("🔍 [MyApp] Deciding start page...");
    final token = await SessionManager.getToken();

    if (token == null) {
      print("   → No token → LoginPage");
      return const LoginPage();
    }

    try {
      final result = await AuthApi.verifySession(
        token,
      ).timeout(const Duration(seconds: 10), onTimeout: () => null);

      if (result != null && result["valid"] == true) {
        final userId = result["userId"] as String;

        // 🔥 THIS WAS MISSING — SAVE userId AFTER VERIFY
        await SessionManager.saveFullSession(
          token,
          await SessionManager.getEmail() ?? "",
          userId,
        );

        print("   ✅ Valid session → MainAppShell (userId: $userId)");
        return MainAppShell(userId: userId);
      }
    } catch (e) {
      print("   ❌ Verify error: $e");
    }

    await SessionManager.clearSession();
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
          return const Scaffold(body: Center(child: Text("Error loading app")));
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
  int _selectedIndex = 1; // AI tab default

  late final List<Widget> _pages = [
    const TasksPage(),
    const AIChatPage(),
    const CalendarPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: const Color.fromARGB(255, 158, 158, 158),
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
