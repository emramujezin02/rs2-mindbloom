import '../../core/network/api_client.dart';
import '../../features/session/presentation/viewmodels/session_viewmodel.dart';
import '../../services/session_storage_service.dart';

import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/services/auth_api_service.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

import '../../features/therapist/data/repositories/therapist_repository.dart';
import '../../features/therapist/data/services/therapist_api_service.dart';
import '../../features/therapist/presentation/viewmodels/therapist_list_viewmodel.dart';

import '../../features/appointment/data/repositories/appointment_repository.dart';
import '../../features/appointment/data/services/appointment_api_service.dart';
import '../../features/appointment/presentation/viewmodels/appointment_create_viewmodel.dart';
import '../../features/appointment/presentation/viewmodels/my_appointments_viewmodel.dart';

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

  static TherapistListViewModel createTherapistListViewModel() {
    final apiService = TherapistApiService(apiClient: apiClient);

    final repository = TherapistRepository(therapistApiService: apiService);

    return TherapistListViewModel(therapistRepository: repository);
  }

  static AppointmentCreateViewModel createAppointmentViewModel() {
    final api = AppointmentApiService(apiClient: apiClient);

    final repository = AppointmentRepository(apiService: api);

    return AppointmentCreateViewModel(repository: repository);
  }

  static MyAppointmentsViewModel createMyAppointmentsViewModel() {
    final api = AppointmentApiService(apiClient: apiClient);

    final repository = AppointmentRepository(apiService: api);

    return MyAppointmentsViewModel(repository: repository);
  }
}
