import 'package:flutter/material.dart';
import 'core/utils/session_manager.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/presentation/home_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _decideStartPage() async {
    final token = await SessionManager.getToken();

    if (token == null) {
      return const LoginPage();
    }

    final result = await AuthApi.verifySession(token);

    if (result != null && result["valid"] == true) {
      final email = result["user"]["email"];
      return HomePage(email: email);
    }

    // invalid or expired token
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
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data!;
        },
      ),
    );
  }
}
