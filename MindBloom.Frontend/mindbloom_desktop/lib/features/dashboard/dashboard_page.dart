import 'package:flutter/material.dart';

import '../../app/router/app_router.dart';
import '../session/session_scope.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MindBloom Admin'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final session = SessionScope.of(context);

              await session.logout();

              if (!context.mounted) {
                return;
              }

              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'MindBloom Admin Dashboard',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
