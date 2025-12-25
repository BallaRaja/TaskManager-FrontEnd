import 'package:flutter/material.dart';
import '../logic/auth_controller.dart';
import 'register_page.dart';
import "..//../../home/presentation/home_page.dart";
import '../../../core/utils/session_manager.dart';

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

  void login() async {
    print("🟡 [LoginPage] Login button pressed");

    setState(() => loading = true);

    try {
      final success = await auth.login(
        emailController.text,
        passwordController.text,
      );

      print("🟢 [LoginPage] Login success: $success");

      if (success) {
        await SessionManager.saveEmail(emailController.text);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(email: emailController.text),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Login Failed")));
      }
    } catch (e) {
      print("❌ [LoginPage] Exception: $e");
    } finally {
      print("🔵 [LoginPage] Loading false");
      setState(() => loading = false);
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
