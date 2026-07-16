import 'package:flutter/material.dart';

import '../../features/admin_shell/data/models/admin_section.dart';
import '../../features/admin_shell/presentation/pages/admin_shell_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/session/presentation/pages/session_gate_page.dart';

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

      default:
        return MaterialPageRoute(builder: (_) => const SessionGatePage());
    }
  }
}
