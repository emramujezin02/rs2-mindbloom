import 'package:mindbloom_desktop/features/reports/data/services/appointment_revenue_pdf_service.dart';
import 'package:mindbloom_desktop/features/review_moderation/presentation/viewmodels/review_moderation_viremodel.dart';
import 'package:mindbloom_desktop/features/workshop_management/presentation/pages/workshop_details_viewmodel.dart';

import '../../core/network/api_client.dart';

import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/services/auth_api_service.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';

import '../../features/membership_management/data/repositories/membership_management_repository.dart';
import '../../features/membership_management/data/services/membership_management_api_service.dart';
import '../../features/membership_management/presentation/viewmodels/membership_management_details_viewmodel.dart';
import '../../features/membership_management/presentation/viewmodels/membership_management_viewmodel.dart';

import '../../features/appointment_management/data/repositories/appointment_management_repository.dart';
import '../../features/appointment_management/data/services/appointment_management_api_service.dart';
import '../../features/appointment_management/presentation/viewmodels/appointment_management_details_viewmodel.dart';
import '../../features/appointment_management/presentation/viewmodels/appointment_management_viewmodel.dart';

import '../../features/payment_management/data/repositories/payment_management_repository.dart';
import '../../features/payment_management/data/services/payment_management_api_service.dart';
import '../../features/payment_management/presentation/viewmodels/payment_management_details_viewmodel.dart';
import '../../features/payment_management/presentation/viewmodels/payment_management_viewmodel.dart';
import '../../features/payment_management/presentation/viewmodels/payment_receipt_viewmodel.dart';

import '../../features/dashboard/data/repositories/admin_dashboard_repository.dart';
import '../../features/dashboard/data/services/admin_dashboard_api_service.dart';
import '../../features/dashboard/presentation/viewmodels/admin_dashboard_viewmodel.dart';

import '../../features/session/presentation/viewmodels/session_viewmodel.dart';

import '../../services/session_storage_service.dart';

import '../../features/users/data/repositories/admin_users_repository.dart';
import '../../features/users/data/services/admin_users_api_service.dart';
import '../../features/users/presentation/viewmodels/admin_users_viewmodel.dart';

import '../../features/therapist_verification/data/repositories/therapist_verification_repository.dart';
import '../../features/therapist_verification/data/services/therapist_verification_api_service.dart';
import '../../features/therapist_verification/presentation/viewmodels/therapist_verification_details_viewmodel.dart';
import '../../features/therapist_verification/presentation/viewmodels/therapist_verification_viewmodel.dart';

import '../../features/review_moderation/data/repositories/review_moderation_repository.dart';
import '../../features/review_moderation/data/services/review_moderation_api_service.dart';
import '../../features/review_moderation/presentation/viewmodels/review_moderation_details_viewmodel.dart';

import '../../features/article_management/data/repositories/article_management_repository.dart';
import '../../features/article_management/data/services/article_management_api_service.dart';
import '../../features/article_management/presentation/viewmodels/article_form_viewmodel.dart';
import '../../features/article_management/presentation/viewmodels/article_management_viewmodel.dart';

import '../../features/workshop_management/data/repositories/workshop_management_repository.dart';
import '../../features/workshop_management/data/services/workshop_management_api_service.dart';
import '../../features/workshop_management/presentation/viewmodels/workshop_form_viewmodel.dart';
import '../../features/workshop_management/presentation/viewmodels/workshop_management_viewmodel.dart';

import '../../features/reference_data/data/repositories/reference_data_repository.dart';
import '../../features/reference_data/data/services/reference_data_api_service.dart';
import '../../features/reference_data/presentation/viewmodels/reference_data_management_viewmodel.dart';

import '../../features/reports/data/repositories/admin_report_repository.dart';
import '../../features/reports/data/services/admin_report_api_service.dart';
import '../../features/reports/presentation/viewmodels/appointment_revenue_report_viewmodel.dart';

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

  static AdminUsersViewModel createAdminUsersViewModel() {
    final apiService = AdminUsersApiService(apiClient: apiClient);

    final repository = AdminUsersRepository(apiService: apiService);

    return AdminUsersViewModel(repository: repository);
  }

  static TherapistVerificationRepository
  _createTherapistVerificationRepository() {
    final apiService = TherapistVerificationApiService(apiClient: apiClient);

    return TherapistVerificationRepository(apiService: apiService);
  }

  static TherapistVerificationViewModel createTherapistVerificationViewModel() {
    return TherapistVerificationViewModel(
      repository: _createTherapistVerificationRepository(),
    );
  }

  static TherapistVerificationDetailsViewModel
  createTherapistVerificationDetailsViewModel() {
    return TherapistVerificationDetailsViewModel(
      repository: _createTherapistVerificationRepository(),
    );
  }

  static ReviewModerationRepository _createReviewModerationRepository() {
    final apiService = ReviewModerationApiService(apiClient: apiClient);

    return ReviewModerationRepository(apiService: apiService);
  }

  static ReviewModerationViewModel createReviewModerationViewModel() {
    return ReviewModerationViewModel(
      repository: _createReviewModerationRepository(),
    );
  }

  static ReviewModerationDetailsViewModel
  createReviewModerationDetailsViewModel() {
    return ReviewModerationDetailsViewModel(
      repository: _createReviewModerationRepository(),
    );
  }

  static AppointmentManagementRepository
  _createAppointmentManagementRepository() {
    final apiService = AppointmentManagementApiService(apiClient: apiClient);

    return AppointmentManagementRepository(apiService: apiService);
  }

  static AppointmentManagementViewModel createAppointmentManagementViewModel() {
    return AppointmentManagementViewModel(
      repository: _createAppointmentManagementRepository(),
    );
  }

  static AppointmentManagementDetailsViewModel
  createAppointmentManagementDetailsViewModel() {
    return AppointmentManagementDetailsViewModel(
      repository: _createAppointmentManagementRepository(),
    );
  }

  static PaymentManagementRepository _createPaymentManagementRepository() {
    final apiService = PaymentManagementApiService(apiClient: apiClient);

    return PaymentManagementRepository(apiService: apiService);
  }

  static PaymentManagementViewModel createPaymentManagementViewModel() {
    return PaymentManagementViewModel(
      repository: _createPaymentManagementRepository(),
    );
  }

  static PaymentManagementDetailsViewModel
  createPaymentManagementDetailsViewModel() {
    return PaymentManagementDetailsViewModel(
      repository: _createPaymentManagementRepository(),
    );
  }

  static PaymentReceiptViewModel createPaymentReceiptViewModel() {
    return PaymentReceiptViewModel(
      repository: _createPaymentManagementRepository(),
    );
  }

  static MembershipManagementRepository
  _createMembershipManagementRepository() {
    final apiService = MembershipManagementApiService(apiClient: apiClient);

    return MembershipManagementRepository(apiService: apiService);
  }

  static MembershipManagementViewModel createMembershipManagementViewModel() {
    return MembershipManagementViewModel(
      repository: _createMembershipManagementRepository(),
    );
  }

  static MembershipManagementDetailsViewModel
  createMembershipManagementDetailsViewModel() {
    return MembershipManagementDetailsViewModel(
      repository: _createMembershipManagementRepository(),
    );
  }

  static ArticleManagementRepository _createArticleManagementRepository() {
    final apiService = ArticleManagementApiService(apiClient: apiClient);

    return ArticleManagementRepository(apiService: apiService);
  }

  static ArticleManagementViewModel createArticleManagementViewModel() {
    return ArticleManagementViewModel(
      repository: _createArticleManagementRepository(),
    );
  }

  static ArticleFormViewModel createArticleFormViewModel() {
    return ArticleFormViewModel(
      repository: _createArticleManagementRepository(),
    );
  }

  static WorkshopManagementRepository _createWorkshopManagementRepository() {
    final apiService = WorkshopManagementApiService(apiClient: apiClient);

    return WorkshopManagementRepository(apiService: apiService);
  }

  static WorkshopManagementViewModel createWorkshopManagementViewModel() {
    return WorkshopManagementViewModel(
      repository: _createWorkshopManagementRepository(),
    );
  }

  static WorkshopFormViewModel createWorkshopFormViewModel() {
    return WorkshopFormViewModel(
      repository: _createWorkshopManagementRepository(),
    );
  }

  static WorkshopDetailsViewModel createWorkshopDetailsViewModel() {
    return WorkshopDetailsViewModel(
      repository: _createWorkshopManagementRepository(),
    );
  }

  static ReferenceDataRepository _createReferenceDataRepository() {
    final apiService = ReferenceDataApiService(apiClient: apiClient);

    return ReferenceDataRepository(apiService: apiService);
  }

  static ReferenceDataManagementViewModel
  createReferenceDataManagementViewModel() {
    return ReferenceDataManagementViewModel(
      repository: _createReferenceDataRepository(),
    );
  }

  static AdminReportRepository _createAdminReportRepository() {
    final apiService = AdminReportApiService(apiClient: apiClient);

    return AdminReportRepository(apiService: apiService);
  }

  static AppointmentRevenueReportViewModel
  createAppointmentRevenueReportViewModel() {
    return AppointmentRevenueReportViewModel(
      repository: _createAdminReportRepository(),
      pdfService: AppointmentRevenuePdfService(),
    );
  }
}
