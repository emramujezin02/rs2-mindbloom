import 'package:flutter/material.dart';
import 'package:mindbloom_desktop/features/appointment_management/presentation/pages/appointment_managemenet_details_page.dart';
import '../../features/review_moderation/presentation/pages/review_moderation_details_page.dart';
import '../../features/admin_shell/data/models/admin_section.dart';
import '../../features/admin_shell/presentation/pages/admin_shell_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/session/presentation/pages/session_gate_page.dart';
import '../../features/therapist_verification/presentation/pages/therapist_verification_details_page.dart';

class AppRouter {
  static const String root = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String users = '/users';
  static const String therapists = '/therapists';
  static const String appointments = '/appointments';
  static const String payments = '/payments';
  static const String memberships = '/memberships';
  static const String workshops = '/workshops';
  static const String articles = '/articles';
  static const String reviews = '/reviews';
  static const String therapistVerificationDetails =
      '/therapists/verification/details';
  static const String reviewModerationDetails = '/reviews/moderation/details';
  static const String appointmentManagementDetails =
      '/appointments/management/details';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case root:
        return MaterialPageRoute(builder: (_) => const SessionGatePage());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case dashboard:
        return MaterialPageRoute(
          builder: (_) =>
              const AdminShellPage(initialSection: AdminSection.dashboard),
        );

      case users:
        return MaterialPageRoute(
          builder: (_) =>
              const AdminShellPage(initialSection: AdminSection.users),
        );

      case therapists:
        return MaterialPageRoute(
          builder: (_) =>
              const AdminShellPage(initialSection: AdminSection.therapists),
        );

      case appointments:
        return MaterialPageRoute(
          builder: (_) =>
              const AdminShellPage(initialSection: AdminSection.appointments),
        );

      case payments:
        return MaterialPageRoute(
          builder: (_) =>
              const AdminShellPage(initialSection: AdminSection.payments),
        );

      case memberships:
        return MaterialPageRoute(
          builder: (_) =>
              const AdminShellPage(initialSection: AdminSection.memberships),
        );

      case workshops:
        return MaterialPageRoute(
          builder: (_) =>
              const AdminShellPage(initialSection: AdminSection.workshops),
        );

      case articles:
        return MaterialPageRoute(
          builder: (_) =>
              const AdminShellPage(initialSection: AdminSection.articles),
        );

      case reviews:
        return MaterialPageRoute(
          builder: (_) =>
              const AdminShellPage(initialSection: AdminSection.reviews),
        );

      case therapistVerificationDetails:
        final therapistId = settings.arguments as int;

        return MaterialPageRoute(
          builder: (_) =>
              TherapistVerificationDetailsPage(therapistId: therapistId),
        );

      case reviewModerationDetails:
        final reviewId = settings.arguments as int;

        return MaterialPageRoute(
          builder: (_) => ReviewModerationDetailsPage(reviewId: reviewId),
        );
      case appointmentManagementDetails:
        final appointmentId = settings.arguments as int;

        return MaterialPageRoute(
          builder: (_) =>
              AppointmentManagementDetailsPage(appointmentId: appointmentId),
        );
      default:
        return MaterialPageRoute(builder: (_) => const SessionGatePage());
    }
  }
}
