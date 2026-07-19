import 'package:flutter/material.dart';
import 'package:mindbloom_mobile/app/di/injection.dart';

import '../../../../app/router/app_router.dart';
import '../../data/models/therapist_dashboard_model.dart';
import '../viewmodels/therapist_dashboard_viewmodel.dart';

class TherapistDashboardPage extends StatefulWidget {
  const TherapistDashboardPage({super.key});

  @override
  State<TherapistDashboardPage> createState() => _TherapistDashboardPageState();
}

class _TherapistDashboardPageState extends State<TherapistDashboardPage> {
  late final TherapistDashboardViewModel viewModel;

  @override
  void initState() {
    super.initState();

    viewModel = AppInjection.createTherapistDashboardViewModel();
    viewModel.addListener(_onViewModelChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.loadDashboard();
    });
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    viewModel.removeListener(_onViewModelChanged);
    viewModel.dispose();

    super.dispose();
  }

  void _openAppointments() {
    Navigator.of(context).pushNamed(AppRouter.therapistAppointments);
  }

  void _openClients() {
  Navigator.of(context).pushNamed(
    AppRouter.therapistClients,
  );
}

  void _openChat() {
    Navigator.of(context).pushNamed(AppRouter.chats);
  }

  void _openNotifications() {
    Navigator.of(context).pushNamed(AppRouter.notifications);
  }

  void _openProfile() {
    Navigator.of(context).pushNamed(AppRouter.profile);
  }

  void _openReviews() {
    Navigator.of(context).pushNamed(AppRouter.myReviews);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Therapist Dashboard',
          style: TextStyle(
            color: Color(0xFF40334D),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: _openProfile,
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: viewModel.refresh, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (viewModel.isLoading && viewModel.dashboard == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.errorMessage != null && viewModel.dashboard == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          _ErrorState(
            message: viewModel.errorMessage!,
            onRetry: viewModel.loadDashboard,
          ),
        ],
      );
    }

    final dashboard = viewModel.dashboard;

    if (dashboard == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(child: Text('Dashboard data is currently unavailable.')),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(22),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _WelcomeSection(),
                const SizedBox(height: 28),
                _StatisticsSection(dashboard: dashboard),
                const SizedBox(height: 28),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 850) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _TodayAppointmentsSection(
                              pendingAppointments:
                                  dashboard.pendingAppointments,
                              onOpenAppointments: _openAppointments,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _ClientsSection(
                              totalAppointments: dashboard.totalAppointments,
                              completedAppointments:
                                  dashboard.completedAppointments,
                              onOpenClients: _openAppointments,
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        _TodayAppointmentsSection(
                          pendingAppointments: dashboard.pendingAppointments,
                          onOpenAppointments: _openAppointments,
                        ),
                        const SizedBox(height: 20),
                        _ClientsSection(
  totalAppointments: dashboard.totalAppointments,
  completedAppointments: dashboard.completedAppointments,
  onOpenClients: _openClients,
),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                _CommunicationSection(
                  onOpenChat: _openChat,
                  onOpenNotifications: _openNotifications,
                ),
                const SizedBox(height: 28),
                _QuickActionsSection(
                  onAppointments: _openAppointments,
                  onChat: _openChat,
                  onNotifications: _openNotifications,
                  onProfile: _openProfile,
                  onReviews: _openReviews,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5291), Color(0xFF9175B2)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_florist_outlined, color: Colors.white, size: 42),
          SizedBox(height: 16),
          Text(
            'Welcome back',
            style: TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 9),
          Text(
            'Review your practice statistics, appointments and communication.',
            style: TextStyle(
              color: Color(0xFFF0EAF7),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsSection extends StatelessWidget {
  final TherapistDashboardModel dashboard;

  const _StatisticsSection({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final statistics = [
      _StatisticData(
        title: 'All appointments',
        value: dashboard.totalAppointments.toString(),
        icon: Icons.calendar_month_outlined,
      ),
      _StatisticData(
        title: 'Completed',
        value: dashboard.completedAppointments.toString(),
        icon: Icons.task_alt_outlined,
      ),
      _StatisticData(
        title: 'Pending',
        value: dashboard.pendingAppointments.toString(),
        icon: Icons.schedule_outlined,
      ),
      _StatisticData(
        title: 'Average rating',
        value: dashboard.averageRating.toStringAsFixed(1),
        icon: Icons.star_outline,
      ),
      _StatisticData(
        title: 'Reviews',
        value: dashboard.totalReviews.toString(),
        icon: Icons.reviews_outlined,
      ),
      _StatisticData(
        title: 'Total earnings',
        value: '${dashboard.totalEarnings.toStringAsFixed(2)} KM',
        icon: Icons.payments_outlined,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Statistics',
          subtitle: 'Overview of your work and client activity.',
        ),
        const SizedBox(height: 17),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth >= 1000
                ? 3
                : constraints.maxWidth >= 600
                ? 2
                : 1;

            const spacing = 16.0;

            final cardWidth =
                (constraints.maxWidth - ((columnCount - 1) * spacing)) /
                columnCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: statistics.map((statistic) {
                return SizedBox(
                  width: cardWidth,
                  child: _StatisticCard(data: statistic),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _StatisticCard extends StatelessWidget {
  final _StatisticData data;

  const _StatisticCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE7DDF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 53,
            height: 53,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE5FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(data.icon, color: const Color(0xFF72559A)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: const TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.title,
                  style: const TextStyle(color: Color(0xFF756D79)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayAppointmentsSection extends StatelessWidget {
  final int pendingAppointments;
  final VoidCallback onOpenAppointments;

  const _TodayAppointmentsSection({
    required this.pendingAppointments,
    required this.onOpenAppointments,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      icon: Icons.today_outlined,
      title: 'Today’s appointments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pendingAppointments == 0
                ? 'You currently have no pending appointments.'
                : 'You have $pendingAppointments pending appointment requests.',
            style: const TextStyle(color: Color(0xFF68616D), height: 1.5),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onOpenAppointments,
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('View appointments'),
          ),
        ],
      ),
    );
  }
}

class _ClientsSection extends StatelessWidget {
  final int totalAppointments;
  final int completedAppointments;
  final VoidCallback onOpenClients;

  const _ClientsSection({
    required this.totalAppointments,
    required this.completedAppointments,
    required this.onOpenClients,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      icon: Icons.people_outline,
      title: 'Clients',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You have managed $totalAppointments appointments, with '
            '$completedAppointments completed sessions.',
            style: const TextStyle(color: Color(0xFF68616D), height: 1.5),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onOpenClients,
            icon: const Icon(Icons.people_outline),
            label: const Text('View client appointments'),
          ),
        ],
      ),
    );
  }
}

class _CommunicationSection extends StatelessWidget {
  final VoidCallback onOpenChat;
  final VoidCallback onOpenNotifications;

  const _CommunicationSection({
    required this.onOpenChat,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Communication',
          subtitle: 'Stay connected with clients and important updates.',
        ),
        const SizedBox(height: 17),
        LayoutBuilder(
          builder: (context, constraints) {
            final chatCard = _CommunicationCard(
              icon: Icons.chat_bubble_outline,
              title: 'Client chat',
              description:
                  'Open conversations connected with your appointments.',
              buttonText: 'Open chat',
              onTap: onOpenChat,
            );

            final notificationCard = _CommunicationCard(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              description:
                  'Review appointment requests, updates and system messages.',
              buttonText: 'View notifications',
              onTap: onOpenNotifications,
            );

            if (constraints.maxWidth >= 700) {
              return Row(
                children: [
                  Expanded(child: chatCard),
                  const SizedBox(width: 16),
                  Expanded(child: notificationCard),
                ],
              );
            }

            return Column(
              children: [
                chatCard,
                const SizedBox(height: 16),
                notificationCard,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CommunicationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onTap;

  const _CommunicationCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      icon: icon,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: const TextStyle(color: Color(0xFF68616D), height: 1.5),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: onTap,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward),
            label: Text(buttonText),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onAppointments;
  final VoidCallback onChat;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onReviews;

  const _QuickActionsSection({
    required this.onAppointments,
    required this.onChat,
    required this.onNotifications,
    required this.onProfile,
    required this.onReviews,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        icon: Icons.calendar_month_outlined,
        title: 'Appointments',
        onTap: onAppointments,
      ),
      _QuickActionData(icon: Icons.chat_outlined, title: 'Chat', onTap: onChat),
      _QuickActionData(
        icon: Icons.notifications_outlined,
        title: 'Notifications',
        onTap: onNotifications,
      ),
      _QuickActionData(
        icon: Icons.reviews_outlined,
        title: 'Reviews',
        onTap: onReviews,
      ),
      _QuickActionData(
        icon: Icons.person_outline,
        title: 'Profile',
        onTap: onProfile,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Quick actions',
          subtitle: 'Open frequently used sections.',
        ),
        const SizedBox(height: 17),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 5
                : constraints.maxWidth >= 560
                ? 3
                : 2;

            const spacing = 14.0;

            final width =
                (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: actions.map((action) {
                return SizedBox(
                  width: width,
                  child: _QuickActionCard(data: action),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final _QuickActionData data;

  const _QuickActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: data.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFE7DDF0)),
          ),
          child: Column(
            children: [
              Icon(data.icon, color: const Color(0xFF72559A), size: 29),
              const SizedBox(height: 11),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF493B55),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _DashboardPanel({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7DDF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE5FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF72559A)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF40334D),
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: Color(0xFF756D79))),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 55, color: Colors.redAccent),
            const SizedBox(height: 17),
            const Text(
              'Dashboard could not be loaded',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticData {
  final String title;
  final String value;
  final IconData icon;

  const _StatisticData({
    required this.title,
    required this.value,
    required this.icon,
  });
}

class _QuickActionData {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}
