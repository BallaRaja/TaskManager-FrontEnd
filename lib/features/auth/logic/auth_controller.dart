import '../data/auth_api.dart';

class AuthController {

  /// 🔐 Login → returns { token, userId }
  Future<Map<String, dynamic>?> login(
      String email, String password) {
    print("➡️ [AuthController] login()");
    return AuthApi.login(email, password);
  }

  /// 📝 Register user
  Future<bool> register(String email, String password) async {
    print("➡️ [AuthController] register()");
    final result = await AuthApi.register(email, password);
    print("⬅️ [AuthController] register result: $result");
    return result;
  }
}
