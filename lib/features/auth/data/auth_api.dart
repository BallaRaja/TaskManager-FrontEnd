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
    print("👤 Name: $name");
    print("📧 Email: $email");

    try {
      final res = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name, "email": email, "password": password}),
      );

      print("⬅️ [AuthApi] REGISTER response code: ${res.statusCode}");
      print("📦 Response body: ${res.body}");

      // ✅ ACCEPT 201 (Created)
      if (res.statusCode == 201) {
        return true;
      }

      final data = jsonDecode(res.body);
      throw Exception(
        data["error"] ?? data["message"] ?? "Registration failed",
      );
    } catch (e) {
      print("❌ [AuthApi] REGISTER exception: $e");
      throw Exception(e.toString().replaceFirst("Exception: ", ""));
    }
  }
}
