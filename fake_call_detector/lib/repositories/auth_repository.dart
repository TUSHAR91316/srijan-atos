import '../services/auth_service.dart';

class AuthRepository {
  AuthRepository({required AuthService authService}) : _authService = authService;

  final AuthService _authService;

  Future<AuthResult> login(String email, String password) {
    return _authService.login(email, password);
  }

  Future<AuthResult> register(String email, String password) {
    return _authService.register(email, password);
  }
}
