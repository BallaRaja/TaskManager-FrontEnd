import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _tokenKey = "jwt_token";
  static const String _emailKey = "user_email";
  static const String _userIdKey = "user_id"; // NEW

  /// Save token + email (existing usage remains valid)
  static Future<void> saveSession(String token, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_emailKey, email);
  }

  /// NEW: Save token + email + userId (use this going forward)
  static Future<void> saveFullSession(
    String token,
    String email,
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_userIdKey, userId);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  /// NEW: Get userId
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Clears ALL stored session data
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
