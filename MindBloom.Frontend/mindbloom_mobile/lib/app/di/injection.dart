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

import '../../features/payment/data/repositories/payment_repository.dart';
import '../../features/payment/data/services/payment_api_service.dart';
import '../../features/payment/presentation/viewmodels/payment_list_viewmodel.dart';

import '../../features/review/data/repositories/review_repository.dart';
import '../../features/review/data/services/review_api_service.dart';
import '../../features/review/presentation/viewmodels/review_list_viewmodel.dart';
import '../../features/review/presentation/viewmodels/create_review_viewmodel.dart';
import '../../features/review/presentation/viewmodels/my_reviews_viewmodel.dart';

import '../../features/profile/data/repositories/profile_repository.dart';
import '../../features/profile/data/services/profile_api_service.dart';
import '../../features/profile/presentation/viewmodels/profile_viewmodel.dart';

import '../../features/dashboard/data/repositories/client_dashboard_repository.dart';
import '../../features/dashboard/data/services/client_dashboard_api_service.dart';
import '../../features/dashboard/presentation/viewmodels/client_dashboard_viewmodel.dart';

import '../../features/notification/data/repositories/notification_repository.dart';
import '../../features/notification/data/services/notification_api_service.dart';
import '../../features/notification/presentation/viewmodels/notification_viewmodel.dart';

import '../../features/membership/data/repositories/membership_repository.dart';
import '../../features/membership/data/services/membership_api_service.dart';
import '../../features/membership/presentation/viewmodels/membership_viewmodel.dart';

import '../../features/journal/data/repositories/journal_repository.dart';
import '../../features/journal/data/services/journal_api_service.dart';
import '../../features/journal/presentation/viewmodels/journal_viewmodel.dart';

import '../../features/article/data/repositories/article_repository.dart';
import '../../features/article/data/services/article_api_service.dart';
import '../../features/article/presentation/viewmodels/article_viewmodel.dart';

import '../../features/workshop/data/repositories/workshop_repository.dart';
import '../../features/workshop/data/services/workshop_api_service.dart';
import '../../features/workshop/presentation/viewmodels/workshop_viewmodel.dart';

class AppInjection {
  static final SessionStorageService sessionStorage = SessionStorageService();

  static final ApiClient apiClient = ApiClient(sessionStorage: sessionStorage);
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

  static PaymentListViewModel createPaymentViewModel() {
    final api = PaymentApiService(apiClient: apiClient);

    final repository = PaymentRepository(apiService: api);

    return PaymentListViewModel(repository: repository);
  }

  static ReviewListViewModel createReviewViewModel() {
    final api = ReviewApiService(apiClient: apiClient);

    final repository = ReviewRepository(apiService: api);

    return ReviewListViewModel(repository: repository);
  }

  static ProfileViewModel createProfileViewModel() {
    final api = ProfileApiService(apiClient: apiClient);

    final repository = ProfileRepository(apiService: api);

    return ProfileViewModel(repository: repository);
  }

  static ClientDashboardViewModel createClientDashboardViewModel() {
    final api = ClientDashboardApiService(apiClient: apiClient);

    final repository = ClientDashboardRepository(apiService: api);

    return ClientDashboardViewModel(repository: repository);
  }

  static CreateReviewViewModel createCreateReviewViewModel() {
    final api = ReviewApiService(apiClient: apiClient);

    final repository = ReviewRepository(apiService: api);

    return CreateReviewViewModel(repository: repository);
  }

  static NotificationViewModel createNotificationViewModel() {
    final api = NotificationApiService(apiClient: apiClient);

    final repository = NotificationRepository(apiService: api);

    return NotificationViewModel(repository: repository);
  }

  static MembershipViewModel createMembershipViewModel() {
    final api = MembershipApiService(apiClient: apiClient);

    final repository = MembershipRepository(apiService: api);

    return MembershipViewModel(repository: repository);
  }

  static JournalViewModel createJournalViewModel() {
    final api = JournalApiService(apiClient: apiClient);

    final repository = JournalRepository(apiService: api);

    return JournalViewModel(repository: repository);
  }

  static ArticleViewModel createArticleViewModel() {
    final api = ArticleApiService(apiClient: apiClient);

    final repository = ArticleRepository(apiService: api);

    return ArticleViewModel(repository: repository);
  }

  static WorkshopViewModel createWorkshopViewModel() {
    final api = WorkshopApiService(apiClient: apiClient);

    final repository = WorkshopRepository(apiService: api);

    return WorkshopViewModel(repository: repository);
  }

  static MyReviewsViewModel createMyReviewsViewModel() {
    final apiService = ReviewApiService(apiClient: apiClient);

    final repository = ReviewRepository(apiService: apiService);

    return MyReviewsViewModel(repository: repository);
  }
}
