import '../../../../core/network/api_client.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';

class AuthApiService {
  final ApiClient apiClient;

  AuthApiService({required this.apiClient});

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await apiClient.post(
      '/Auth/login',
      body: request.toJson(),
    );

    return AuthResponse.fromJson(response);
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    final response = await apiClient.post(
      '/Auth/register',
      body: request.toJson(),
    );

    return AuthResponse.fromJson(response);
  }
}
