import 'package:flutter/material.dart';
import '../data/auth_api.dart';
import '../../../core/theme/app_theme.dart';
import 'otp_verification_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  final ValueChanged<bool>? onThemeChanged;

  const ForgotPasswordPage({super.key, this.onThemeChanged});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  final otpController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  
  int _currentStep = 0; // 0: Email, 1: OTP & New Password
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    emailController.dispose();
    otpController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = "Email is required");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await AuthApi.forgotPassword(email);
      if (success) {
        setState(() => _currentStep = 1);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = emailController.text.trim();
    final otp = otpController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (otp.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = "All fields are required");
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = "Passwords do not match");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await AuthApi.resetPassword(email, otp, password);
      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password reset successful! Please login.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final secondaryColor = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Forgot Password"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Icon(
                _currentStep == 0 ? Icons.lock_reset : Icons.vpn_key_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                _currentStep == 0 ? "Reset Password" : "Enter Verification Code",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 12),
              Text(
                _currentStep == 0 
                  ? "Enter your email to receive a recovery code" 
                  : "Check your email for the 6-digit code",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: secondaryColor),
              ),
              const SizedBox(height: 48),
              if (_currentStep == 0) ...[
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: textColor),
                  decoration: _buildDecoration("Email", Icons.email_outlined),
                ),
              ] else ...[
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: _buildDecoration("6-Digit Code", Icons.pin_outlined),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: textColor),
                  decoration: _buildDecoration("New Password", Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Theme.of(context).colorScheme.primary),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: _obscureConfirm,
                  style: TextStyle(color: textColor),
                  decoration: _buildDecoration("Confirm New Password", Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Theme.of(context).colorScheme.primary),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14)),
              ],
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _currentStep == 0 ? _sendOTP : _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                        ),
                        child: Text(
                          _currentStep == 0 ? "Send Code" : "Reset Password",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
    );
  }
}
