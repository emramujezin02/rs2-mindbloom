import 'package:flutter/material.dart';
import 'package:mindbloom_desktop/features/appointment_management/presentation/pages/appointment_managemenet_details_page.dart';
import 'package:mindbloom_desktop/features/common/presentation/page/not_found_page.dart';

import '../../features/admin_shell/data/models/admin_section.dart';
import '../../features/admin_shell/presentation/pages/admin_shell_page.dart';
import '../../features/article_management/presentation/pages/article_form_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/membership_management/presentation/pages/membership_management_details_page.dart';
import '../../features/payment_management/presentation/pages/payment_management_details_page.dart';
import '../../features/payment_management/presentation/pages/payment_receipt_page.dart';
import '../../features/review_moderation/presentation/pages/review_moderation_details_page.dart';
import '../../features/session/presentation/pages/admin_route_guard.dart';
import '../../features/session/presentation/pages/session_gate_page.dart';
import '../../features/therapist_verification/presentation/pages/therapist_verification_details_page.dart';
import '../../features/workshop_management/presentation/pages/workshop_details_page.dart';
import '../../features/workshop_management/presentation/pages/workshop_form_page.dart';
import '../../features/payment_management/data/models/payment_route_arguments.dart';

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

  static const String referenceData = '/reference-data';

  static const String appointmentRevenueReport = '/reports/appointment-revenue';

  static const String therapistPerformanceReport =
      '/reports/therapist-performance';

  static const String auditLogs = '/audit-logs';

  static const String settings = '/settings';

  static const String therapistVerificationDetails =
      '/therapists/verification/details';

  static const String reviewModerationDetails = '/reviews/moderation/details';

  static const String appointmentManagementDetails =
      '/appointments/management/details';

  static const String paymentManagementDetails = '/payments/management/details';

  static const String paymentReceipt = '/payments/receipt';

  static const String membershipManagementDetails =
      '/memberships/management/details';

  static const String articleManagementForm = '/articles/management/form';

  static const String workshopManagementForm = '/workshops/management/form';

  static const String workshopManagementDetails =
      '/workshops/management/details';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case root:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SessionGatePage(),
        );

      case login:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginPage(),
        );

      case dashboard:
        return _adminShellRoute(settings, AdminSection.dashboard);

      case users:
        return _adminShellRoute(settings, AdminSection.users);

      case therapists:
        return _adminShellRoute(settings, AdminSection.therapists);

      case appointments:
        return _adminShellRoute(settings, AdminSection.appointments);

      case payments:
        return _adminShellRoute(settings, AdminSection.payments);

      case memberships:
        return _adminShellRoute(settings, AdminSection.memberships);

      case reviews:
        return _adminShellRoute(settings, AdminSection.reviews);

      case articles:
        return _adminShellRoute(settings, AdminSection.articles);

      case workshops:
        return _adminShellRoute(settings, AdminSection.workshops);

      case referenceData:
        return _adminShellRoute(settings, AdminSection.referenceData);

      case auditLogs:
        return _adminShellRoute(settings, AdminSection.auditLogs);

      case appointmentRevenueReport:
        return _adminShellRoute(
          settings,
          AdminSection.appointmentRevenueReport,
        );

      case therapistPerformanceReport:
        return _adminShellRoute(
          settings,
          AdminSection.therapistPerformanceReport,
        );

      case AppRouter.settings:
        return _adminShellRoute(settings, AdminSection.settings);

      case therapistVerificationDetails:
        final therapistId = settings.arguments as int;

        return _guardedRoute(
          settings,
          TherapistVerificationDetailsPage(therapistId: therapistId),
        );

      case reviewModerationDetails:
        final reviewId = settings.arguments as int;

        return _guardedRoute(
          settings,
          ReviewModerationDetailsPage(reviewId: reviewId),
        );

      case appointmentManagementDetails:
        final appointmentId = settings.arguments as int;

        return _guardedRoute(
          settings,
          AppointmentManagementDetailsPage(appointmentId: appointmentId),
        );

      case paymentManagementDetails:
        final arguments = settings.arguments as PaymentRouteArguments;

        return MaterialPageRoute(
          builder: (_) => PaymentManagementDetailsPage(
            paymentId: arguments.paymentId,
            paymentType: arguments.paymentType,
          ),
        );
      case paymentReceipt:
        final arguments = settings.arguments as PaymentRouteArguments;

        return MaterialPageRoute(
          builder: (_) => PaymentReceiptPage(
            paymentId: arguments.paymentId,
            paymentType: arguments.paymentType,
          ),
        );

      case membershipManagementDetails:
        final membershipId = settings.arguments as int;

        return _guardedRoute(
          settings,
          MembershipManagementDetailsPage(membershipId: membershipId),
        );

      case articleManagementForm:
        final articleId = settings.arguments as int?;

        return _guardedRoute(settings, ArticleFormPage(articleId: articleId));

      case workshopManagementForm:
        final workshopId = settings.arguments as int?;

        return _guardedRoute(
          settings,
          WorkshopFormPage(workshopId: workshopId),
        );

      case workshopManagementDetails:
        final workshopId = settings.arguments as int;

        return _guardedRoute(
          settings,
          WorkshopDetailsPage(workshopId: workshopId),
        );

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const NotFoundPage(),
        );
    }
  }

  static MaterialPageRoute<dynamic> _adminShellRoute(
    RouteSettings settings,
    AdminSection section,
  ) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) {
        return AdminRouteGuard(child: AdminShellPage(initialSection: section));
      },
    );
  }

  static MaterialPageRoute<dynamic> _guardedRoute(
    RouteSettings settings,
    Widget child,
  ) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) {
        return AdminRouteGuard(child: child);
      },
    );
  }
}
