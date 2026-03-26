import '../services/auth_service.dart';
import '../services/security_service.dart';

class AuthRepository {
  AuthRepository({required AuthService authService}) : _authService = authService;

  final AuthService _authService;

  Future<AuthResult> login(String email, String password) async {
    final result = await _authService.login(email, password);
    if (result.success) {
      await SecurityService.instance.saveSession(email);
    }
    return result;
  }

  Future<AuthResult> register(String email, String password) {
    return _authService.register(email, password);
  }

  Future<void> logout() {
    return SecurityService.instance.clearSession();
  }
}
