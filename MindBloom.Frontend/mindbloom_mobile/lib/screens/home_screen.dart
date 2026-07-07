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
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    session.isLoggedIn
                        ? 'You are logged in.'
                        : 'You are not logged in.',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (!session.isLoggedIn)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.login);
                      },
                      child: const Text('Go to login'),
                    ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
