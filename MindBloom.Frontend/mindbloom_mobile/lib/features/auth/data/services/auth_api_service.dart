import '../../../../core/network/api_client.dart';
import '../models/auth_response.dart';
import '../models/change_password_request.dart';
import '../models/forgot_password_request.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../models/reset_password_request.dart';

class AuthApiService {
  final ApiClient apiClient;

  AuthApiService({required this.apiClient});

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await apiClient.post(
      '/Auth/login',
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

  Future<void> logout() async {
    await apiClient.post('/Auth/logout');
  }
}
