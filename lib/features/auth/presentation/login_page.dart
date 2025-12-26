import 'package:flutter/material.dart';
import '../logic/auth_controller.dart';
import 'register_page.dart';
import '../../../core/utils/session_manager.dart';
import '../../../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final auth = AuthController();

  bool loading = false;

  Future<void> login() async {
    if (loading) return; // prevent double tap

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email and password are required")),
      );
      return;
    }

    print("🟡 [LoginPage] Login button pressed");
    setState(() => loading = true);

    try {
      final result = await auth.login(email, password);

      print("🟢 [LoginPage] Login result: $result");

      if (result != null &&
          result["token"] != null &&
          result["userId"] != null) {
        await SessionManager.saveFullSession(
          result["token"], // JWT token
          email, // user email
          result["userId"], // userId from backend
        );

        print("✅ [LoginPage] Session saved");

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyApp()),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invalid login response")));
      }
    } catch (e) {
      print("❌ [LoginPage] Exception: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login failed")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),

            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: login, child: const Text("Login")),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                );
              },
              child: const Text("Create account"),
            ),
          ],
        ),
      ),
    );
  }
}
