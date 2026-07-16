import 'package:flutter/material.dart';

import '../auth/presentation/pages/login_page.dart';
import '../dashboard/dashboard_page.dart';
import 'session_scope.dart';

class SessionGatePage extends StatelessWidget {
  const SessionGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    if (!session.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!session.isLoggedIn) {
      return const LoginPage();
    }

    return const DashboardPage();
  }
}
