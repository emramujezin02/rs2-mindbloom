import 'package:flutter/material.dart';

import '../../../auth/presentation/pages/login_page.dart';
import '../viewmodels/session_scope.dart';

class AdminRouteGuard extends StatelessWidget {
  final Widget child;

  const AdminRouteGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    if (!session.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAdmin = session.isLoggedIn && session.currentUser?.isAdmin == true;

    if (!isAdmin) {
      return const LoginPage();
    }

    return child;
  }
}
