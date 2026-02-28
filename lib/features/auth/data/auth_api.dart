import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';

class AuthApi {
  /// 🔐 Verify JWT session with backend
  static Future<Map<String, dynamic>?> verifySession(String token) async {
    print("➡️ [AuthApi] verifySession() called");
    print("   URL: ${ApiConstants.baseUrl}/verify");
    print("   Token: ${token.substring(0, 20)}...");

    try {
      final res = await http
          .get(
            Uri.parse("${ApiConstants.baseUrl}/verify"),
            headers: {"Authorization": "Bearer $token"},
          )
          .timeout(const Duration(seconds: 8));

      print("⬅️ [AuthApi] verify status: ${res.statusCode}");
      print("   Body: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        print("   Decoded: $data");
        return data;
      }

      if (res.statusCode == 401 || res.statusCode == 403) {
        return {"valid": false, "unauthorized": true};
      }

      print("❌ Verify failed - status: ${res.statusCode}");
      return null;
    } catch (e) {
      print("❌ [AuthApi] Verify exception: $e");
      return null;
    }
  }

  /// 🔐 Login user → expects { token, userId }
  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    print("➡️ [AuthApi] login() called");
    print("   Email: $email");

    try {
      final res = await http
          .post(
            Uri.parse("${ApiConstants.baseUrl}/login"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 8));

      print("⬅️ [AuthApi] login status: ${res.statusCode}");
      print("   Body: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        print("   Decoded: $data");
        return data;
      }

      final data = jsonDecode(res.body);
      throw Exception(data["error"] ?? "Login failed");
    } catch (e) {
      print("❌ [AuthApi] Login exception: $e");
      throw Exception(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  /// 📝 Register user (no JWT here)
  static Future<bool> register(
    String name,
    String email,
    String password,
  ) async {
    print("➡️ [AuthApi] REGISTER called");
    try {
      final res = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name, "email": email, "password": password}),
      );

      if (res.statusCode == 201) return true;

      final data = jsonDecode(res.body);
      throw Exception(data["error"] ?? "Registration failed");
    } catch (e) {
      throw Exception(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  /// 📧 Verify OTP
  static Future<bool> verifyOtp(String email, String otp) async {
    print("➡️ [AuthApi] verifyOtp called");
    try {
      final res = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "otp": otp}),
      );

      if (res.statusCode == 200) return true;

      final data = jsonDecode(res.body);
      throw Exception(data["error"] ?? "Verification failed");
    } catch (e) {
      throw Exception(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  /// 🔑 Forgot Password
  static Future<bool> forgotPassword(String email) async {
    try {
      final res = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );
      if (res.statusCode == 200) return true;
      final data = jsonDecode(res.body);
      throw Exception(data["error"] ?? "Forgot password request failed");
    } catch (e) {
      throw Exception(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  /// 🔑 Reset Password
  static Future<bool> resetPassword(String email, String otp, String newPassword) async {
    try {
      final res = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/reset-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "otp": otp, "newPassword": newPassword}),
      );
      if (res.statusCode == 200) return true;
      final data = jsonDecode(res.body);
      throw Exception(data["error"] ?? "Reset password failed");
    } catch (e) {
      throw Exception(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  /// 🔑 Change Password
  static Future<bool> changePassword(String token, String oldPassword, String newPassword) async {
    try {
      final res = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/change-password"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"oldPassword": oldPassword, "newPassword": newPassword}),
      );
      if (res.statusCode == 200) return true;
      final data = jsonDecode(res.body);
      throw Exception(data["error"] ?? "Change password failed");
    } catch (e) {
      throw Exception(e.toString().replaceFirst("Exception: ", ""));
    }
  }
}
