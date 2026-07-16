import 'package:flutter/material.dart';

import '../../../session/presentation/viewmodels/session_scope.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    final currentUser = session.currentUser;

    final username = currentUser?.username.trim() ?? '';

    final email = currentUser?.email ?? '';

    final displayName = username.isNotEmpty ? username : 'Administrator';

    return SingleChildScrollView(
      key: const PageStorageKey<String>('admin-dashboard'),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $displayName',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            email.isEmpty
                ? 'MindBloom administration dashboard'
                : 'Signed in as $email',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnCount = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 720
                  ? 2
                  : 1;

              final itemWidth =
                  (constraints.maxWidth - ((columnCount - 1) * 16)) /
                  columnCount;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _DashboardSummaryCard(
                    width: itemWidth,
                    icon: Icons.people,
                    title: 'Users',
                    value: '—',
                    description: 'Registered users',
                  ),
                  _DashboardSummaryCard(
                    width: itemWidth,
                    icon: Icons.psychology,
                    title: 'Therapists',
                    value: '—',
                    description: 'Approved therapists',
                  ),
                  _DashboardSummaryCard(
                    width: itemWidth,
                    icon: Icons.calendar_month,
                    title: 'Appointments',
                    value: '—',
                    description: 'Total appointments',
                  ),
                  _DashboardSummaryCard(
                    width: itemWidth,
                    icon: Icons.payments,
                    title: 'Revenue',
                    value: '—',
                    description: 'Completed payments',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 18),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MindBloom Administration',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Use the navigation sidebar to manage users, '
                          'therapists, appointments, payments, memberships, '
                          'workshops, articles and reviews.',
                          style: TextStyle(fontSize: 15, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSummaryCard extends StatelessWidget {
  final double width;

  final IconData icon;

  final String title;

  final String value;

  final String description;

  const _DashboardSummaryCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 34,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
