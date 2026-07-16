import '../../core/network/api_client.dart';

import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/services/auth_api_service.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

import '../../features/session/session_viewmodel.dart';

import '../../services/session_storage_service.dart';

class AppInjection {
  static final SessionStorageService sessionStorage = SessionStorageService();

  static final ApiClient apiClient = ApiClient(sessionStorage: sessionStorage);

  static final AuthApiService _authApiService = AuthApiService(
    apiClient: apiClient,
  );

  static final AuthRepository _authRepository = AuthRepository(
    apiService: _authApiService,
    sessionStorage: sessionStorage,
  );

  static SessionViewModel createSessionViewModel() {
    return SessionViewModel(
      sessionStorage: sessionStorage,
      authRepository: _authRepository,
    );
  }

  static AuthViewModel createAuthViewModel() {
    return AuthViewModel(repository: _authRepository);
  }
}
