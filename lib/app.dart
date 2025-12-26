import 'package:flutter/material.dart';
import 'core/utils/session_manager.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/presentation/home_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _decideStartPage() async {
    print("🔍 [MyApp] Deciding start page...");
    final token = await SessionManager.getToken();
    print("   Token from storage: ${token != null ? 'exists' : 'null'}");

    if (token == null) {
      print("   → No token → LoginPage");
      return const LoginPage();
    }

    print("   → Verifying token...");
    try {
      // Add timeout to prevent hanging forever
      final result = await AuthApi.verifySession(token).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print("   ⏰ Verify request timed out");
          return null;
        },
      );

      if (result != null && result["valid"] == true) {
        final userId = result["userId"] as String?;
        print("   ✅ Token valid → HomePage (userId: $userId)");
        return HomePage(userId: userId ?? "unknown");
      } else {
        print("   ❌ Token invalid or response null");
      }
    } catch (e, stack) {
      print("   ❌ Verify error: $e");
      print("   Stack: $stack");
    }

    print("   → Clearing invalid session");
    await SessionManager.clearSession();
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Widget>(
        future: _decideStartPage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Checking session..."),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            print("FutureBuilder error: ${snapshot.error}");
            return Scaffold(
              body: Center(
                child: Text("Error: ${snapshot.error}"),
              ),
            );
          }

          if (snapshot.hasData) {
            return snapshot.data!;
          }

          return const Scaffold(
            body: Center(child: Text("Something went wrong")),
          );
        },
      ),
    );
  }
}