import 'package:flutter/material.dart';
import '../../../core/utils/session_manager.dart';
import '../../auth/presentation/login_page.dart';

class HomePage extends StatelessWidget {
  final String email;

  const HomePage({super.key, required this.email});

  void logout(BuildContext context) async {
    await SessionManager.clearSession();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          )
        ],
      ),
      body: Center(
        child: Text(
          'Hello, $email 👋',
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
