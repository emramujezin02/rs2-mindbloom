import 'package:flutter/material.dart';
import 'package:mindbloom_mobile/features/about/presentation/page/about_page.dart';
import 'package:mindbloom_mobile/features/private_journal/presentation/pages/private_journal_page.dart';
import '../../screens/home_screen.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/auth/presentation/pages/two_factor_settings_page.dart';
import '../../features/auth/presentation/pages/verify_2fa_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';

import '../../features/therapist/presentation/pages/therapist_list_page.dart';
import '../../features/therapist/presentation/pages/therapist_details_page.dart';
import '../../features/therapist/data/models/therapist_model.dart';

import '../../features/appointment/presentation/pages/appointment_create_page.dart';
import '../../features/appointment/presentation/pages/my_appointments_page.dart';
import '../../features/appointment/presentation/pages/appointment_details_page.dart';
import '../../features/appointment/data/models/appointment_model.dart';

import '../../features/payment/presentation/pages/payment_list_page.dart';

import '../../features/review/presentation/pages/review_list_page.dart';
import '../../features/review/presentation/pages/create_review_page.dart';
import '../../features/review/presentation/pages/my_reviews_page.dart';

import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/data/models/profile_model.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';

import '../../features/dashboard/presentation/pages/client_dashboard_page.dart';

import '../../features/notification/presentation/pages/notification_page.dart';

import '../../features/membership/presentation/pages/my_memberships_page.dart';
import '../../features/membership/presentation/pages/purchase_membership_page.dart';
import '../../features/membership/presentation/pages/use_membership_page.dart';

import '../../features/journal/presentation/pages/journal_page.dart';
import '../../features/journal/presentation/pages/add_journal_entry_page.dart';
import '../../features/journal/data/models/journal_entry_model.dart';
import '../../features/journal/presentation/pages/edit_journal_entry_page.dart';
import '../../features/journal/presentation/pages/journal_entry_details_page.dart';

import '../../features/article/presentation/pages/article_details_page.dart';
import '../../features/article/presentation/pages/article_list_page.dart';

import '../../features/workshop/presentation/pages/workshop_page.dart';
import '../../features/workshop/presentation/pages/workshop_details_page.dart';
import '../../features/workshop/presentation/pages/my_workshop_registrations_page.dart';

import '../../features/favorite/presentation/pages/my_favorites_page.dart';

import '../../features/chat/presentation/pages/chat_details_page.dart';
import '../../features/chat/presentation/pages/chat_list_page.dart';

import '../../features/recommendation/presentation/pages/recommendation_page.dart';

import '../../features/therapist/presentation/pages/therapist_dashboard_page.dart';

import '../../features/appointment/presentation/pages/therapist_appointments_page.dart';
import '../../features/appointment/presentation/pages/therapist_appointment_details_page.dart';

import '../../features/therapist/presentation/pages/therapist_client_details_page.dart';
import '../../features/therapist/presentation/pages/therapist_clients_page.dart';
import '../../features/therapist/data/models/therapist_emotional_analytics_arguments.dart';
import '../../features/therapist/data/models/therapist_profile_model.dart';
import '../../features/therapist/presentation/pages/therapist_edit_profile_page.dart';

import '../../features/therapist/presentation/pages/therapist_emotional_analytics_page.dart';
import '../../features/therapist/data/models/therapist_list_arguments.dart';
import '../../features/journal/presentation/pages/client_emotional_analytics_page.dart';

import '../../features/private_journal/data/models/private_journal_entry_model.dart';
import '../../features/private_journal/presentation/pages/add_private_journal_entry_page.dart';
import '../../features/private_journal/presentation/pages/edit_private_journal_entry_page.dart';
import '../../features/private_journal/presentation/pages/private_journal_entry_details_page.dart';
import '../../features/onboarding/presentation/pages/client_onboarding_page.dart';

class AppRouter {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String therapists = '/therapists';
  static const String therapistDetails = '/therapist-details';
  static const appointmentCreate = "/appointments/create";
  static const String myAppointments = '/appointments/mine';
  static const appointmentDetails = '/appointments/details';
  static const myPayments = '/payments';
  static const therapistReviews = '/therapists/reviews';
  static const profile = '/profile';
  static const clientDashboard = '/client-dashboard';
  static const createReview = '/reviews/create';
  static const notifications = '/notifications';
  static const myMemberships = '/memberships/mine';
  static const purchaseMembership = '/memberships/purchase';
  static const useMembership = '/memberships/use';
  static const journal = '/journal';
  static const addJournalEntry = '/journal/add';
  static const editProfile = '/profile/edit';
  static const articles = '/articles';
  static const articleDetails = '/articles/details';
  static const workshops = '/workshops';
  static const String changePassword = '/change-password';
  static const String myReviews = '/reviews/mine';
  static const String verify2FA = '/verify-2fa';
  static const String twoFactorSettings = '/profile/two-factor';
  static const String verifyEmail = '/verify-email';
  static const String myFavorites = '/favorites/mine';
  static const String journalEntryDetails = '/journal/details';
  static const String editJournalEntry = '/journal/edit';
  static const String workshopDetails = '/workshops/details';
  static const String myWorkshopRegistrations = '/workshops/mine';
  static const String chats = '/chat';
  static const String chatDetails = '/chat/details';
  static const String recommendations = '/recommendations';
  static const about = '/about';
  static const String therapistDashboard = '/therapist-dashboard';
  static const String therapistAppointments = '/therapist/appointments';
  static const String therapistAppointmentDetails =
      '/therapist/appointments/details';
  static const String therapistClients = '/therapist/clients';
  static const String therapistClientDetails = '/therapist/clients/details';
  static const String therapistEditProfile = '/therapist/edit-profile';
  static const String therapistEmotionalAnalytics =
      '/therapist/clients/emotional-analytics';
  static const String clientEmotionalAnalytics = '/journal/analytics';
  static const String privateJournal = '/private-journal';
  static const String onboarding = '/client-onboarding';
  static const String addPrivateJournalEntry = '/private-journal/add';

  static const String privateJournalEntryDetails = '/private-journal/details';

  static const String editPrivateJournalEntry = '/private-journal/edit';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());

      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());

      case resetPassword:
        final email = settings.arguments as String;

        return MaterialPageRoute(
          builder: (_) => ResetPasswordPage(email: email),
        );

      case therapists:
        final arguments = settings.arguments;

        return MaterialPageRoute(
          builder: (_) => TherapistListPage(
            arguments: arguments is TherapistListArguments ? arguments : null,
          ),
          settings: settings,
        );

      case therapistDetails:
        final therapistId = settings.arguments as int;

        return MaterialPageRoute(
          builder: (_) => TherapistDetailsPage(therapistId: therapistId),
        );

      case appointmentCreate:
        final therapist = settings.arguments as TherapistModel;

        return MaterialPageRoute(
          builder: (_) => AppointmentCreatePage(therapist: therapist),
        );

      case myAppointments:
        return MaterialPageRoute(builder: (_) => const MyAppointmentsPage());

      case appointmentDetails:
        final appointment = settings.arguments as AppointmentModel;

        return MaterialPageRoute(
          builder: (_) => AppointmentDetailsPage(appointment: appointment),
        );

      case myPayments:
        return MaterialPageRoute(builder: (_) => const PaymentListPage());

      case therapistReviews:
        final therapistId = settings.arguments as int;

        return MaterialPageRoute(
          builder: (_) => ReviewListPage(therapistId: therapistId),
        );

      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());

      case clientDashboard:
        return MaterialPageRoute(builder: (_) => const ClientDashboardPage());

      case createReview:
        final appointment = settings.arguments as AppointmentModel;

        return MaterialPageRoute(
          builder: (_) => CreateReviewPage(appointment: appointment),
        );

      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationPage());

      case myMemberships:
        return MaterialPageRoute(builder: (_) => const MyMembershipsPage());

      case purchaseMembership:
        final therapist = settings.arguments as TherapistModel;

        return MaterialPageRoute(
          builder: (_) => PurchaseMembershipPage(therapist: therapist),
        );

      case useMembership:
        final appointment = settings.arguments as AppointmentModel;

        return MaterialPageRoute(
          builder: (_) => UseMembershipPage(appointment: appointment),
        );

      case journal:
        return MaterialPageRoute(builder: (_) => const JournalPage());

      case addJournalEntry:
        return MaterialPageRoute(builder: (_) => const AddJournalEntryPage());

      case editProfile:
        final profile = settings.arguments as ProfileModel;

        return MaterialPageRoute(
          builder: (_) => EditProfilePage(profile: profile),
        );

      case articles:
        return MaterialPageRoute(builder: (_) => const ArticleListPage());

      case articleDetails:
        final articleId = settings.arguments as int;

        return MaterialPageRoute(
          builder: (_) => ArticleDetailsPage(articleId: articleId),
        );

      case workshops:
        return MaterialPageRoute(builder: (_) => const WorkshopPage());

      case changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordPage());

      case myReviews:
        return MaterialPageRoute(builder: (_) => const MyReviewsPage());

      case verify2FA:
        final email = settings.arguments as String;

        return MaterialPageRoute(builder: (_) => Verify2FAPage(email: email));

      case twoFactorSettings:
        return MaterialPageRoute(builder: (_) => const TwoFactorSettingsPage());

      case verifyEmail:
        final email = settings.arguments as String;

        return MaterialPageRoute(builder: (_) => VerifyEmailPage(email: email));

      case myFavorites:
        return MaterialPageRoute(builder: (_) => const MyFavoritesPage());

      case journalEntryDetails:
        final entryId = settings.arguments as int;

        return MaterialPageRoute(
          builder: (_) => JournalEntryDetailsPage(entryId: entryId),
        );

      case editJournalEntry:
        final entry = settings.arguments as JournalEntryModel;

        return MaterialPageRoute(
          builder: (_) => EditJournalEntryPage(entry: entry),
        );

      case workshopDetails:
        final workshopId = settings.arguments as int;

        return MaterialPageRoute(
          builder: (_) => WorkshopDetailsPage(workshopId: workshopId),
        );

      case myWorkshopRegistrations:
        return MaterialPageRoute(
          builder: (_) => const MyWorkshopRegistrationsPage(),
        );

      case chats:
        return MaterialPageRoute(builder: (_) => const ChatListPage());

      case chatDetails:
        final appointmentId = settings.arguments as int;

        return MaterialPageRoute(
          builder: (_) => ChatDetailsPage(appointmentId: appointmentId),
        );
      case recommendations:
        return MaterialPageRoute(builder: (_) => const RecommendationPage());

      case therapistAppointments:
        return MaterialPageRoute(
          builder: (_) => const TherapistAppointmentsPage(),
        );

      case therapistAppointmentDetails:
        final appointment = settings.arguments as AppointmentModel;

        return MaterialPageRoute(
          builder: (_) =>
              TherapistAppointmentDetailsPage(appointment: appointment),
        );

      case therapistDashboard:
        return MaterialPageRoute(
          builder: (_) => const TherapistDashboardPage(),
        );

      case therapistEditProfile:
        final profile = settings.arguments as TherapistProfileModel;

        return MaterialPageRoute(
          builder: (_) => TherapistEditProfilePage(profile: profile),
          settings: settings,
        );

      case about:
        return MaterialPageRoute(builder: (_) => const AboutPage());

      case therapistClients:
        return MaterialPageRoute(
          builder: (_) => const TherapistClientsPage(),
          settings: settings,
        );

      case therapistClientDetails:
        final clientId = settings.arguments;

        if (clientId is! int) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Client identifier is missing.')),
            ),
            settings: settings,
          );
        }

        return MaterialPageRoute(
          builder: (_) => TherapistClientDetailsPage(clientId: clientId),
          settings: settings,
        );

      case therapistEmotionalAnalytics:
        final arguments = settings.arguments;

        if (arguments is! TherapistEmotionalAnalyticsArguments) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(
                child: Text(
                  'Client analytics information '
                  'is missing.',
                ),
              ),
            ),
            settings: settings,
          );
        }

        return MaterialPageRoute(
          builder: (_) => TherapistEmotionalAnalyticsPage(
            clientId: arguments.clientId,
            clientName: arguments.clientName,
          ),
          settings: settings,
        );

      case clientEmotionalAnalytics:
        return MaterialPageRoute(
          builder: (_) => const ClientEmotionalAnalyticsPage(),
          settings: settings,
        );

      case privateJournal:
        return MaterialPageRoute(builder: (_) => const PrivateJournalPage());

      case addPrivateJournalEntry:
        return MaterialPageRoute(
          builder: (_) => const AddPrivateJournalEntryPage(),
        );

      case privateJournalEntryDetails:
        final entryId = settings.arguments as int;

        return MaterialPageRoute(
          builder: (_) => PrivateJournalEntryDetailsPage(entryId: entryId),
        );

      case editPrivateJournalEntry:
        final entry = settings.arguments as PrivateJournalEntryModel;

        return MaterialPageRoute(
          builder: (_) => EditPrivateJournalEntryPage(entry: entry),
        );

      case onboarding:
        return MaterialPageRoute(
          builder: (_) => const ClientOnboardingPage(),
          settings: settings,
        );

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
