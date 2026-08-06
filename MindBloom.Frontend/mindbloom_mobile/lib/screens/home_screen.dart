import 'package:flutter/material.dart';

import '../core/widgets/app_loading_widget.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/navigation/presentation/pages/client_navigation_shell.dart';
import '../features/navigation/presentation/pages/therapist_navigation_shell.dart';
import '../features/notification/presentation/viewmodels/notification_scope.dart';
import '../features/onboarding/presentation/pages/client_onboarding_gate.dart';
import '../features/session/presentation/viewmodels/session_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _notificationInitializationRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final session = SessionScope.of(context);
    final notifications = NotificationScope.of(context);

    if (session.isInitialized &&
        session.isLoggedIn &&
        !_notificationInitializationRequested) {
      _notificationInitializationRequested = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        notifications.initialize();
      });
    }

    if (session.isInitialized && !session.isLoggedIn) {
      _notificationInitializationRequested = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    if (!session.isInitialized) {
      return const Scaffold(
        body: AppLoadingWidget(message: 'Loading MindBloom...'),
      );
    }

    if (!session.isLoggedIn) {
      return const LoginPage();
    }

    if (session.isTherapist) {
      return const TherapistNavigationShell();
    }

    return const ClientOnboardingGate(child: ClientNavigationShell());
  }
}
