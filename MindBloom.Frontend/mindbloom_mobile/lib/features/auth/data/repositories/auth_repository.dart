import '../../../../services/session_storage_service.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../services/auth_api_service.dart';
import '../models/forgot_password_request.dart';
import '../models/reset_password_request.dart';
import '../models/change_password_request.dart';

class AuthRepository {
  final AuthApiService authApiService;
  final SessionStorageService sessionStorage;

  AuthRepository({required this.authApiService, required this.sessionStorage});

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await authApiService.login(request);

    await sessionStorage.saveToken(response.token);

    await sessionStorage.saveRefreshToken(response.refreshToken);

    return response;
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await authApiService.register(request);

    await sessionStorage.saveToken(response.token);

    await sessionStorage.saveRefreshToken(response.refreshToken);

    return response;
  }

  Future<void> forgotPassword(ForgotPasswordRequest request) async {
    await authApiService.forgotPassword(request);
  }

  Future<void> resetPassword(ResetPasswordRequest request) async {
    await authApiService.resetPassword(request);
  }

  Future<void> changePassword(ChangePasswordRequest request) async {
    await authApiService.changePassword(request);
  }

  Future<bool> logout() async {
    var serverLogoutSucceeded = true;

    try {
      await authApiService.logout();
    } catch (_) {
      serverLogoutSucceeded = false;
    } finally {
      await sessionStorage.clearSession();
    }

    return serverLogoutSucceeded;
  }
}
