import '../../core/network/api_client.dart';
import '../../features/session/presentation/viewmodels/session_viewmodel.dart';
import '../../services/session_storage_service.dart';

class AppInjection {
  static final ApiClient apiClient = ApiClient();

  static final SessionStorageService sessionStorage = SessionStorageService();

  static SessionViewModel createSessionViewModel() {
    return SessionViewModel(sessionStorage: sessionStorage);
  }
}
