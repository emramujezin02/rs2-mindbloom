import 'package:flutter/material.dart';

import '../core/debug/mindbloom_debug_log.dart';
import '../core/widgets/app_loading_widget.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/navigation/presentation/pages/client_navigation_shell.dart';
import '../features/navigation/presentation/pages/therapist_navigation_shell.dart';
import '../features/onboarding/presentation/pages/client_onboarding_gate.dart';
import '../features/session/presentation/viewmodels/session_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final session = SessionScope.of(context);

    logWidget(
      'HomeScreen.didChangeDependencies '
      'sessionInitialized=${session.isInitialized} '
      'isLoggedIn=${session.isLoggedIn} '
      'role=${session.role ?? "none"}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    logWidget(
      'HomeScreen.build '
      'sessionInitialized=${session.isInitialized} '
      'isLoggedIn=${session.isLoggedIn} '
      'role=${session.role ?? "none"}',
    );

    if (!session.isInitialized) {
      logWidget('HomeScreen first screen = AppLoadingWidget');

      return const Scaffold(
        body: AppLoadingWidget(message: 'Loading MindBloom...'),
      );
    }

    if (!session.isLoggedIn) {
      logWidget('HomeScreen first screen = LoginPage');

      return const LoginPage();
    }

    if (session.isTherapist) {
      logWidget('HomeScreen first screen = TherapistNavigationShell');

      return const TherapistNavigationShell();
    }

    logWidget('HomeScreen first screen = ClientOnboardingGate');

    return const ClientOnboardingGate(child: ClientNavigationShell());
  }
}
