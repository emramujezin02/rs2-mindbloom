import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../session/presentation/viewmodels/session_scope.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    final destination = session.isLoggedIn
        ? AppRouter.dashboard
        : AppRouter.login;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.travel_explore,
                  size: 96,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Page not found',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'The page you requested does not exist or is no longer available.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil(destination, (route) => false);
                  },
                  icon: Icon(
                    session.isLoggedIn ? Icons.dashboard : Icons.login,
                  ),
                  label: Text(
                    session.isLoggedIn
                        ? 'Return to dashboard'
                        : 'Return to login',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
