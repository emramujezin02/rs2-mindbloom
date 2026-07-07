import 'package:flutter/material.dart';

import '../../features/dashboard/dashboard_page.dart';

class AppRouter {
  static const String dashboard = '/';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardPage());

      default:
        return MaterialPageRoute(builder: (_) => const DashboardPage());
    }
  }
}
