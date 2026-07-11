import '../../../../services/session_storage_service.dart';
import '../models/auth_response.dart';
import '../models/change_password_request.dart';
import '../models/forgot_password_request.dart';
import '../models/login_2fa_response.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../models/reset_password_request.dart';
import '../models/verify_2fa_request.dart';
import '../services/auth_api_service.dart';

class AuthRepository {
  final AuthApiService authApiService;
  final SessionStorageService sessionStorage;

  AuthRepository({required this.authApiService, required this.sessionStorage});

  Future<Login2FAResponse> login(LoginRequest request) async {
    final response = await authApiService.login(request);

    final auth = response.auth;

    if (!response.requiresTwoFactor && auth != null) {
      await sessionStorage.saveTokens(
        accessToken: auth.token,
        refreshToken: auth.refreshToken,
      );
    }

    return response;
  }

  Future<AuthResponse> verify2FA(Verify2FARequest request) async {
    final response = await authApiService.verify2FA(request);

    await sessionStorage.saveTokens(
      accessToken: response.token,
      refreshToken: response.refreshToken,
    );

    return response;
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await authApiService.register(request);

    await sessionStorage.saveTokens(
      accessToken: response.token,
      refreshToken: response.refreshToken,
    );

    return response;
  }

  Future<void> forgotPassword(ForgotPasswordRequest request) {
    return authApiService.forgotPassword(request);
  }

  Future<void> resetPassword(ResetPasswordRequest request) {
    return authApiService.resetPassword(request);
  }

  Future<void> changePassword(ChangePasswordRequest request) {
    return authApiService.changePassword(request);
  }

  Future<bool> get2FAStatus() {
    return authApiService.get2FAStatus();
  }

  Future<void> enable2FA() {
    return authApiService.enable2FA();
  }

  Future<void> disable2FA() {
    return authApiService.disable2FA();
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
