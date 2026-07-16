import 'package:flutter/material.dart';

import '../../../admin_shell/presentation/pages/admin_shell_page.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../viewmodels/session_scope.dart';

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

    return const AdminShellPage();
  }
}
