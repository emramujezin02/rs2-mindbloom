import '../../../../core/network/api_client.dart';
import '../models/auth_response.dart';
import '../models/change_password_request.dart';
import '../models/forgot_password_request.dart';
import '../models/login_2fa_response.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../models/reset_password_request.dart';
import '../models/verify_2fa_request.dart';
import '../models/send_email_verification_code_request.dart';
import '../models/verify_email_code_request.dart';

class AuthApiService {
  final ApiClient apiClient;

  AuthApiService({required this.apiClient});

  Future<Login2FAResponse> login(LoginRequest request) async {
    final response = await apiClient.post(
      '/Auth/login-2fa',
      body: request.toJson(),
      requiresAuth: false,
    );

    return Login2FAResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<AuthResponse> verify2FA(Verify2FARequest request) async {
    final response = await apiClient.post(
      '/Auth/verify-2fa',
      body: request.toJson(),
      requiresAuth: false,
    );

    return AuthResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await apiClient.post(
      '/Auth/register',
      body: request.toJson(),
      requiresAuth: false,
    );

    return AuthResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<void> forgotPassword(ForgotPasswordRequest request) async {
    await apiClient.post(
      '/Auth/forgot-password',
      body: request.toJson(),
      requiresAuth: false,
    );
  }

  Future<void> resetPassword(ResetPasswordRequest request) async {
    await apiClient.post(
      '/Auth/reset-password',
      body: request.toJson(),
      requiresAuth: false,
    );
  }

  Future<void> changePassword(ChangePasswordRequest request) async {
    await apiClient.post('/Auth/change-password', body: request.toJson());
  }

  Future<bool> get2FAStatus() async {
    final response = await apiClient.get('/Auth/2fa-status');

    return response['isEnabled'] ?? false;
  }

  Future<void> enable2FA() async {
    await apiClient.post('/Auth/enable-2fa');
  }

  Future<void> disable2FA() async {
    await apiClient.post('/Auth/disable-2fa');
  }

  Future<void> logout() async {
    await apiClient.post('/Auth/logout');
  }

  Future<void> sendEmailVerificationCode(
    SendEmailVerificationCodeRequest request,
  ) async {
    await apiClient.post(
      '/Auth/send-verification-code',
      body: request.toJson(),
      requiresAuth: false,
    );
  }

  Future<void> verifyEmailCode(VerifyEmailCodeRequest request) async {
    await apiClient.post(
      '/Auth/verify-email-code',
      body: request.toJson(),
      requiresAuth: false,
    );
  }
}
