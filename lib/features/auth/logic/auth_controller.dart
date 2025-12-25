import '../data/auth_api.dart';

class AuthController {

  Future<bool> login(String email, String password) async {
    print("➡️ [AuthController] login()");
    final result = await AuthApi.login(email, password);
    print("⬅️ [AuthController] login result: $result");
    return result;
  }

  Future<bool> register(String email, String password) async {
    print("➡️ [AuthController] register()");
    final result = await AuthApi.register(email, password);
    print("⬅️ [AuthController] register result: $result");
    return result;
  }
}
