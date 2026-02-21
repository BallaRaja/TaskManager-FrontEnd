import 'package:client/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import '../logic/auth_controller.dart';
import '../../../core/theme/app_theme.dart';

// Custom wave clipper for the top section
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 60);

    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 30);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width * 3 / 4, size.height - 60);
    var secondEndPoint = Offset(size.width, size.height - 20);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class RegisterPage extends StatefulWidget {
  final ValueChanged<bool>? onThemeChanged;

  const RegisterPage({super.key, this.onThemeChanged});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final auth = AuthController();

  bool loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _showErrorPopup(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Registration Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void register() async {
    print("🟡 [RegisterPage] Register button pressed");

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      await _showErrorPopup(
        "Name, email, password and confirm password are required",
      );
      return;
    }

    if (password != confirmPassword) {
      await _showErrorPopup("Password and confirm password do not match");
      return;
    }

    setState(() => loading = true);

    try {
      final success = await auth.register(name, email, password);

      print("🟢 [RegisterPage] Register success: $success");

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration successful. Please login."),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LoginPage(onThemeChanged: widget.onThemeChanged),
          ),
        );
      } else {
        await _showErrorPopup("Registration failed");
      }
    } catch (e) {
      print("❌ [RegisterPage] Exception: $e");
      await _showErrorPopup(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      print("🔵 [RegisterPage] Loading false");
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputTextColor = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final inputSecondaryColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final borderColor = isDark
        ? AppTheme.darkInactiveIcons
        : AppTheme.lightInactiveIcons;
    final headerStartColor = isDark
        ? const Color(0xFF2A2342)
        : const Color(0xFF5B6DEE);
    final headerEndColor = isDark
        ? const Color(0xFF1E1A2B)
        : const Color(0xFF4D5FDE);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top section with wave
            ClipPath(
              clipper: _WaveClipper(),
              child: Container(
                height: screenHeight * 0.35,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [headerStartColor, headerEndColor],
                  ),
                ),
                child: Stack(
                  children: [
                    // Back button
                    Positioned(
                      top: 40,
                      left: 16,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    // Title
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 60),
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Form section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Name Field
                  TextField(
                    controller: nameController,
                    keyboardType: TextInputType.name,
                    style: TextStyle(fontSize: 16, color: inputTextColor),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(
                        color: inputSecondaryColor,
                        fontSize: 14,
                      ),
                      hintText: 'Your name',
                      hintStyle: TextStyle(
                        color: inputSecondaryColor,
                        fontSize: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email Field
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: 16, color: inputTextColor),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(
                        color: inputSecondaryColor,
                        fontSize: 14,
                      ),
                      hintText: 'test@gmail.com',
                      hintStyle: TextStyle(
                        color: inputSecondaryColor,
                        fontSize: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Password Field
                  TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(fontSize: 16, color: inputTextColor),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(
                        color: inputSecondaryColor,
                        fontSize: 14,
                      ),
                      hintText: '••••••',
                      hintStyle: TextStyle(
                        color: inputSecondaryColor,
                        fontSize: 20,
                        letterSpacing: 4,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: inputSecondaryColor,
                          size: 22,
                        ),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Confirm Password Field
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: TextStyle(fontSize: 16, color: inputTextColor),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: TextStyle(
                        color: inputSecondaryColor,
                        fontSize: 14,
                      ),
                      hintText: '••••••',
                      hintStyle: TextStyle(
                        color: inputSecondaryColor,
                        fontSize: 20,
                        letterSpacing: 4,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          );
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: inputSecondaryColor,
                          size: 22,
                        ),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: loading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : ElevatedButton(
                            onPressed: register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(27),
                              ),
                            ),
                            child: const Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Sign In Link
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: RichText(
                      text: TextSpan(
                        text: "Already have an account? ",
                        style: TextStyle(
                          color: inputSecondaryColor,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
