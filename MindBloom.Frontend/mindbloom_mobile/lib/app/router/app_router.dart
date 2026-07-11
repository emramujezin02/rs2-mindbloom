import 'package:flutter/material.dart';
import '../../screens/home_screen.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';

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

import '../../features/article/data/models/article_model.dart';
import '../../features/article/presentation/pages/article_details_page.dart';
import '../../features/article/presentation/pages/article_list_page.dart';

import '../../features/workshop/presentation/pages/workshop_page.dart';

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
        return MaterialPageRoute(builder: (_) => const TherapistListPage());

      case therapistDetails:
        final therapist = settings.arguments as TherapistModel;

        return MaterialPageRoute(
          builder: (_) => TherapistDetailsPage(therapist: therapist),
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
        final article = settings.arguments as ArticleModel;

        return MaterialPageRoute(
          builder: (_) => ArticleDetailsPage(article: article),
        );

      case workshops:
        return MaterialPageRoute(builder: (_) => const WorkshopPage());

      case changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordPage());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
