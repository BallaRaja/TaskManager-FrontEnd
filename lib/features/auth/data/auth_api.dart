import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';

class AuthApi {
  static Future<Map<String, dynamic>?> verifySession(String token) async {
    try {
      final res = await http.get(
        Uri.parse("${ApiConstants.baseUrl}/verify"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print("❌ Verify session error: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    try {
      final res = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print("❌ Login API error: $e");
      return null;
    }
  }

  static Future<bool> register(String email, String password) async {
    print("➡️ [AuthApi] REGISTER called");
    print("📧 Email: $email");

    try {
      final res = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      print("⬅️ [AuthApi] REGISTER response code: ${res.statusCode}");
      print("📦 Response body: ${res.body}");

      return res.statusCode == 200;
    } catch (e) {
      print("❌ [AuthApi] REGISTER exception: $e");
      return false;
    }
  }
}
