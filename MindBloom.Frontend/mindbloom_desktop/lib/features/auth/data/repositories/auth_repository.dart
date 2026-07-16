import '../../../../services/session_storage_service.dart';
import '../models/current_user_model.dart';
import '../models/login_request.dart';
import '../services/auth_api_service.dart';

class AuthRepository {
  final AuthApiService apiService;

  final SessionStorageService sessionStorage;

  AuthRepository({required this.apiService, required this.sessionStorage});

  Future<CurrentUserModel> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final response = await apiService.login(
      LoginRequest(email: email, password: password, rememberMe: rememberMe),
    );

    if (!response.isAdmin) {
      await sessionStorage.clearSession();

      throw Exception(
        'Access denied. The desktop application is available only to administrators.',
      );
    }

    if (response.token.trim().isEmpty || response.refreshToken.trim().isEmpty) {
      throw Exception('The server did not return valid authentication tokens.');
    }

    await sessionStorage.saveSession(
      accessToken: response.token.trim(),
      refreshToken: response.refreshToken.trim(),
      role: response.role.trim(),
    );

    final currentUser = await apiService.getCurrentUser();

    if (!currentUser.isAdmin) {
      await sessionStorage.clearSession();

      throw Exception('Access denied. Administrator role is required.');
    }

    return currentUser;
  }

  Future<CurrentUserModel> getCurrentUser() {
    return apiService.getCurrentUser();
  }

  Future<void> logout() async {
    try {
      await apiService.logout();
    } finally {
      await sessionStorage.clearSession();
    }
  }
}
