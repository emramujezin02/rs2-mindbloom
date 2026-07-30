import '../../../../core/network/api_client.dart';
import '../models/auth_response_model.dart';
import '../models/current_user_model.dart';
import '../models/login_request.dart';

class AuthApiService {
  final ApiClient apiClient;

  AuthApiService({required this.apiClient});

  Future<AuthResponseModel> login(LoginRequest request) async {
    final response = await apiClient.post(
      '/Auth/login',
      body: request.toJson(),
      requiresAuth: false,
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('The server returned an invalid login response.');
    }

    return AuthResponseModel.fromJson(response);
  }

  Future<CurrentUserModel> getCurrentUser() async {
    final response = await apiClient.get('/Auth/me');

    if (response is! Map<String, dynamic>) {
      throw Exception('The server returned invalid user data.');
    }

    return CurrentUserModel.fromJson(response);
  }

  Future<void> logout() async {
    await apiClient.post('/Auth/logout');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await apiClient.post(
      '/Auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }
}
