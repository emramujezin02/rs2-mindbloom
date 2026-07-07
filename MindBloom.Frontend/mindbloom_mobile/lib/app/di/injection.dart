import '../../core/network/api_client.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/services/auth_api_service.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/session/presentation/viewmodels/session_viewmodel.dart';
import '../../services/session_storage_service.dart';

class AppInjection {
  static final ApiClient apiClient = ApiClient();

  static final SessionStorageService sessionStorage = SessionStorageService();

  static SessionViewModel createSessionViewModel() {
    return SessionViewModel(sessionStorage: sessionStorage);
  }

  static AuthViewModel createAuthViewModel() {
    final authApiService = AuthApiService(apiClient: apiClient);

    final authRepository = AuthRepository(
      authApiService: authApiService,
      sessionStorage: sessionStorage,
    );

    return AuthViewModel(authRepository: authRepository);
  }
}
