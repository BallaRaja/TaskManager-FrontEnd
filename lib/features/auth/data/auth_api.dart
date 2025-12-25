import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';

class AuthApi {
  static Future<bool> login(String email, String password) async {
    print("➡️ [AuthApi] LOGIN called");
    print("📧 Email: $email");

    try {
      final res = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      print("⬅️ [AuthApi] LOGIN response code: ${res.statusCode}");
      print("📦 Response body: ${res.body}");

      return res.statusCode == 200;
    } catch (e) {
      print("❌ [AuthApi] LOGIN exception: $e");
      return false;
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
