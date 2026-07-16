import '../../core/network/api_client.dart';

import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/services/auth_api_service.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

import '../../features/dashboard/data/repositories/admin_dashboard_repository.dart';
import '../../features/dashboard/data/services/admin_dashboard_api_service.dart';
import '../../features/dashboard/presentation/viewmodels/admin_dashboard_viewmodel.dart';

import '../../features/session/presentation/viewmodels/session_viewmodel.dart';

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

  static AdminDashboardViewModel createAdminDashboardViewModel() {
    final apiService = AdminDashboardApiService(apiClient: apiClient);

    final repository = AdminDashboardRepository(apiService: apiService);

    return AdminDashboardViewModel(repository: repository);
  }
}
