import '../../../../services/session_storage_service.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../services/auth_api_service.dart';

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
}
