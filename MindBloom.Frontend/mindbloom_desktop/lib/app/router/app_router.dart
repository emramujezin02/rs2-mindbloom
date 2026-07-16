import 'package:flutter/material.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/session/session_gate_page.dart';

class AppRouter {
  static const String root = '/';

  static const String login = '/login';

  static const String dashboard = '/dashboard';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case root:
        return MaterialPageRoute(builder: (_) => const SessionGatePage());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardPage());

      default:
        return MaterialPageRoute(builder: (_) => const SessionGatePage());
    }
  }
}
