import 'package:flutter/material.dart';
import 'core/utils/session_manager.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/presentation/home_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<String?>(
        future: SessionManager.getEmail(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.data != null) {
            return HomePage(email: snapshot.data!);
          }

          return const LoginPage();
        },
      ),
    );
  }
}
