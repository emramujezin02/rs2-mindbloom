import 'package:flutter/material.dart';

import '../app/router/app_router.dart';
import '../features/session/presentation/session_scope.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MindBloom'),
        actions: [
          if (session.isLoggedIn)
            IconButton(
              onPressed: () async {
                await session.logout();

                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed(AppRouter.login);
                }
              },
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Center(
        child: session.isInitialized
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      session.isLoggedIn
                          ? 'Welcome to MindBloom'
                          : 'You are not logged in.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (session.isLoggedIn)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRouter.clientDashboard);
                        },
                        child: const Text('My dashboard'),
                      ),

                    if (session.isLoggedIn) const SizedBox(height: 12),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRouter.notifications);
                      },
                      icon: const Icon(Icons.notifications),
                      label: const Text('Notifications'),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.therapists);
                      },
                      child: const Text('Browse therapists'),
                    ),

                    const SizedBox(height: 12),

                    if (session.isLoggedIn)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRouter.myAppointments);
                        },
                        child: const Text('My appointments'),
                      ),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRouter.myMemberships);
                      },
                      icon: const Icon(Icons.card_membership),
                      label: const Text('My memberships'),
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.myPayments);
                      },
                      child: const Text('Payment history'),
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.profile);
                      },
                      child: const Text('My profile'),
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRouter.journal);
                      },
                      icon: const Icon(Icons.menu_book),
                      label: const Text("Journal"),
                    ),

                    const SizedBox(height: 12),

                    if (!session.isLoggedIn)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRouter.login);
                        },
                        child: const Text('Login'),
                      ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
