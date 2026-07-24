import 'package:mindbloom_mobile/features/appointment/presentation/viewmodels/therapist_appointments_viewmodel.dart';
import 'package:mindbloom_mobile/features/landing/presentation/viewmodels/landing_page_viewmodel.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/viewmodels/therapist_dashboard_viewmodel.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/viewmodels/therapist_profile_viewmodel.dart';

import '../../core/network/api_client.dart';
import '../../features/session/presentation/viewmodels/session_viewmodel.dart';
import '../../services/session_storage_service.dart';

import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/services/auth_api_service.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

import '../../features/therapist/data/repositories/therapist_repository.dart';
import '../../features/therapist/data/services/therapist_api_service.dart';
import '../../features/therapist/presentation/viewmodels/therapist_list_viewmodel.dart';
import '../../features/therapist/presentation/viewmodels/therapist_details_viewmodel.dart';

import '../../features/appointment/data/repositories/appointment_repository.dart';
import '../../features/appointment/data/services/appointment_api_service.dart';
import '../../features/appointment/presentation/viewmodels/appointment_create_viewmodel.dart';
import '../../features/appointment/presentation/viewmodels/my_appointments_viewmodel.dart';
import '../../features/appointment/data/models/appointment_model.dart';
import '../../features/appointment/presentation/viewmodels/appointment_details_viewmodel.dart';

import '../../features/payment/data/repositories/payment_repository.dart';
import '../../features/payment/data/services/payment_api_service.dart';
import '../../features/payment/presentation/viewmodels/payment_list_viewmodel.dart';
import '../../features/payment/presentation/viewmodels/appointment_payment_viewmodel.dart';

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
import '../../features/notification/data/services/notification_realtime_service.dart';

import '../../features/membership/data/repositories/membership_repository.dart';
import '../../features/membership/data/services/membership_api_service.dart';
import '../../features/membership/presentation/viewmodels/membership_viewmodel.dart';

import '../../features/journal/data/repositories/journal_repository.dart';
import '../../features/journal/data/services/journal_api_service.dart';
import '../../features/journal/presentation/viewmodels/journal_viewmodel.dart';

import '../../features/article/data/repositories/article_repository.dart';
import '../../features/article/presentation/viewmodels/article_viewmodel.dart';
import '../../features/article/data/services/article_api_service.dart';

import '../../features/workshop/data/repositories/workshop_repository.dart';
import '../../features/workshop/data/services/workshop_api_service.dart';
import '../../features/workshop/presentation/viewmodels/workshop_viewmodel.dart';

import '../../features/favorite/data/repositories/favorite_repository.dart';
import '../../features/favorite/data/services/favorite_api_service.dart';
import '../../features/favorite/presentation/viewmodels/favorite_list_viewmodel.dart';

import '../../features/chat/data/repositories/chat_repository.dart';
import '../../features/chat/data/services/chat_api_service.dart';
import '../../features/chat/data/services/chat_realtime_service.dart';
import '../../features/chat/presentation/viewmodels/chat_details_viewmodel.dart';
import '../../features/chat/presentation/viewmodels/chat_list_viewmodel.dart';

import '../../features/recommendation/data/repositories/recommendation_repository.dart';
import '../../features/recommendation/data/services/recommendation_api_service.dart';
import '../../features/recommendation/presentation/viewmodels/recommendation_viewmodel.dart';

import '../../features/therapist/presentation/viewmodels/therapist_clients_viewmodel.dart';
import '../../features/therapist/presentation/viewmodels/therapist_client_details_viewmodel.dart';

import '../../features/therapist/presentation/viewmodels/therapist_emotional_analytics_viewmodel.dart';
import '../../features/therapy_approach/data/repositories/therapy_approach_repository.dart';
import '../../features/therapy_approach/data/services/therapy_approach_api_service.dart';

import '../../features/journal/presentation/viewmodels/client_emotional_analytics_viewmodel.dart';

class AppInjection {
  static final SessionStorageService sessionStorage = SessionStorageService();
  static final ApiClient apiClient = ApiClient(sessionStorage: sessionStorage);

  static final NotificationRepository _notificationRepository =
      NotificationRepository(
        apiService: NotificationApiService(apiClient: apiClient),
      );

  static SessionViewModel createSessionViewModel() {
    final authApiService = AuthApiService(apiClient: apiClient);

    final authRepository = AuthRepository(
      authApiService: authApiService,
      sessionStorage: sessionStorage,
    );

    return SessionViewModel(
      sessionStorage: sessionStorage,
      authRepository: authRepository,
    );
  }

  static ClientEmotionalAnalyticsViewModel
  createClientEmotionalAnalyticsViewModel() {
    final api = JournalApiService(apiClient: apiClient);

    final repository = JournalRepository(apiService: api);

    return ClientEmotionalAnalyticsViewModel(repository: repository);
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

    final therapistRepository = TherapistRepository(
      therapistApiService: apiService,
    );

    return TherapistListViewModel(
      therapistRepository: therapistRepository,
      favoriteRepository: _createFavoriteRepository(),
    );
  }

  static AppointmentCreateViewModel createAppointmentViewModel() {
    final apiService = AppointmentApiService(apiClient: apiClient);

    final repository = AppointmentRepository(apiService: apiService);

    return AppointmentCreateViewModel(repository: repository);
  }

  static MyAppointmentsViewModel createMyAppointmentsViewModel() {
    final api = AppointmentApiService(apiClient: apiClient);

    final repository = AppointmentRepository(apiService: api);

    return MyAppointmentsViewModel(repository: repository);
  }

  static PaymentRepository _createPaymentRepository() {
    final apiService = PaymentApiService(apiClient: apiClient);

    return PaymentRepository(apiService: apiService);
  }

  static PaymentListViewModel createPaymentViewModel() {
    return PaymentListViewModel(repository: _createPaymentRepository());
  }

  static AppointmentPaymentViewModel createAppointmentPaymentViewModel() {
    return AppointmentPaymentViewModel(repository: _createPaymentRepository());
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

  static final NotificationViewModel _notificationViewModel =
      NotificationViewModel(
        repository: _notificationRepository,
        realtimeServiceFactory:
            ({
              required onNotificationReceived,
              required onReconnected,
              required onConnectionStatusChanged,
            }) {
              return NotificationRealtimeService(
                sessionStorage: sessionStorage,
                onNotificationReceived: onNotificationReceived,
                onReconnected: onReconnected,
                onConnectionStatusChanged: onConnectionStatusChanged,
              );
            },
      );

  static NotificationViewModel createNotificationViewModel() {
    return _notificationViewModel;
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

  static TherapistDetailsViewModel createTherapistDetailsViewModel() {
    final apiService = TherapistApiService(apiClient: apiClient);

    final therapistRepository = TherapistRepository(
      therapistApiService: apiService,
    );

    return TherapistDetailsViewModel(
      repository: therapistRepository,
      favoriteRepository: _createFavoriteRepository(),
    );
  }

  static AppointmentDetailsViewModel createAppointmentDetailsViewModel(
    AppointmentModel appointment,
  ) {
    final apiService = AppointmentApiService(apiClient: apiClient);

    final repository = AppointmentRepository(apiService: apiService);

    return AppointmentDetailsViewModel(
      repository: repository,
      appointment: appointment,
    );
  }

  static FavoriteRepository _createFavoriteRepository() {
    final apiService = FavoriteApiService(apiClient: apiClient);

    return FavoriteRepository(apiService: apiService);
  }

  static FavoriteListViewModel createFavoriteListViewModel() {
    return FavoriteListViewModel(repository: _createFavoriteRepository());
  }

  static ChatRepository _createChatRepository() {
    final apiService = ChatApiService(apiClient: apiClient);

    return ChatRepository(apiService: apiService);
  }

  static ChatListViewModel createChatListViewModel() {
    return ChatListViewModel(repository: _createChatRepository());
  }

  static ChatDetailsViewModel createChatDetailsViewModel() {
    return ChatDetailsViewModel(
      repository: _createChatRepository(),
      realtimeServiceFactory:
          ({
            required onMessageReceived,
            required onStatusChanged,
            required onReconnected,
          }) {
            return ChatRealtimeService(
              sessionStorage: sessionStorage,
              onMessageReceived: onMessageReceived,
              onStatusChanged: onStatusChanged,
              onReconnected: onReconnected,
            );
          },
    );
  }

  static RecommendationApiService createRecommendationApiService() {
    return RecommendationApiService(apiClient: apiClient);
  }

  static RecommendationRepository createRecommendationRepository() {
    return RecommendationRepository(
      apiService: createRecommendationApiService(),
    );
  }

  static RecommendationViewModel createRecommendationViewModel() {
    return RecommendationViewModel(
      repository: createRecommendationRepository(),
    );
  }

  static LandingPageViewModel createLandingPageViewModel() {
    final therapistApiService = TherapistApiService(apiClient: apiClient);

    final therapistRepository = TherapistRepository(
      therapistApiService: therapistApiService,
    );

    final articleApiService = ArticleApiService(apiClient: apiClient);

    final articleRepository = ArticleRepository(apiService: articleApiService);

    final reviewApiService = ReviewApiService(apiClient: apiClient);

    final reviewRepository = ReviewRepository(apiService: reviewApiService);

    final therapyApproachApiService = TherapyApproachApiService(
      apiClient: apiClient,
    );

    final therapyApproachRepository = TherapyApproachRepository(
      apiService: therapyApproachApiService,
    );

    return LandingPageViewModel(
      therapistRepository: therapistRepository,
      articleRepository: articleRepository,
      reviewRepository: reviewRepository,
      therapyApproachRepository: therapyApproachRepository,
    );
  }

  static TherapistDashboardViewModel createTherapistDashboardViewModel() {
    final apiService = TherapistApiService(apiClient: apiClient);

    final repository = TherapistRepository(therapistApiService: apiService);

    return TherapistDashboardViewModel(repository: repository);
  }

  static TherapistAppointmentsViewModel createTherapistAppointmentsViewModel() {
    final apiService = AppointmentApiService(apiClient: apiClient);

    final repository = AppointmentRepository(apiService: apiService);

    return TherapistAppointmentsViewModel(repository: repository);
  }

  static TherapistRepository _createTherapistRepository() {
    final apiService = TherapistApiService(apiClient: apiClient);

    return TherapistRepository(therapistApiService: apiService);
  }

  static TherapistClientsViewModel createTherapistClientsViewModel() {
    return TherapistClientsViewModel(repository: _createTherapistRepository());
  }

  static TherapistClientDetailsViewModel
  createTherapistClientDetailsViewModel() {
    return TherapistClientDetailsViewModel(
      repository: _createTherapistRepository(),
    );
  }

  static TherapistProfileViewModel createTherapistProfileViewModel() {
    final apiService = TherapistApiService(apiClient: apiClient);

    final repository = TherapistRepository(therapistApiService: apiService);

    return TherapistProfileViewModel(repository: repository);
  }

  static TherapistEmotionalAnalyticsViewModel
  createTherapistEmotionalAnalyticsViewModel() {
    return TherapistEmotionalAnalyticsViewModel(
      repository: _createTherapistRepository(),
    );
  }
}
