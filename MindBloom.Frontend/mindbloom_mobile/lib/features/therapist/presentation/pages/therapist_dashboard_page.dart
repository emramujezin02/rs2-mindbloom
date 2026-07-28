import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/therapist_dashboard_model.dart';
import '../viewmodels/therapist_dashboard_viewmodel.dart';

class TherapistDashboardPage extends StatefulWidget {
  const TherapistDashboardPage({super.key});

  @override
  State<TherapistDashboardPage> createState() => _TherapistDashboardPageState();
}

class _TherapistDashboardPageState extends State<TherapistDashboardPage> {
  late final TherapistDashboardViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createTherapistDashboardViewModel();

    _viewModel.addListener(_onChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _viewModel.loadDashboard();
      }
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openAppointments() {
    Navigator.of(context).pushNamed(AppRouter.therapistAppointments);
  }

  void _openClients() {
    Navigator.of(context).pushNamed(AppRouter.therapistClients);
  }

  void _openProfile() {
    Navigator.of(context).pushNamed(AppRouter.profile);
  }

  void _openAvailability() {
    Navigator.of(context).pushNamed(AppRouter.profile);
  }

  void _openChat() {
    Navigator.of(context).pushNamed(AppRouter.chats);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _viewModel.refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.dashboard == null) {
      return const AppLoadingWidget.skeleton(
        message: 'Učitavanje kontrolne ploče...',
        skeletonItemCount: 7,
      );
    }

    if (_viewModel.errorMessage != null && _viewModel.dashboard == null) {
      return AppErrorWidget(
        title: 'Kontrolnu ploču nije moguće učitati',
        error: _viewModel.errorMessage,
        onRetry: _viewModel.loadDashboard,
      );
    }

    final dashboard = _viewModel.dashboard;

    if (dashboard == null) {
      return const AppEmptyStateWidget(
        title: 'Kontrolna ploča nije dostupna',
        message: 'Podaci kontrolne ploče trenutno nisu dostupni.',
        icon: Icons.dashboard_outlined,
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (_viewModel.errorMessage != null) ...[
          AppInlineError(
            title: 'Podaci nisu mogli biti osvježeni',
            error: _viewModel.errorMessage,
            onRetry: _viewModel.refresh,
          ),
          const SizedBox(height: 16),
        ],
        const _WelcomeCard(),
        const SizedBox(height: 24),
        _DashboardStatistics(dashboard: dashboard),
        const SizedBox(height: 28),
        _QuickActions(
          onAppointments: _openAppointments,
          onClients: _openClients,
          onProfile: _openProfile,
          onAvailability: _openAvailability,
          onChat: _openChat,
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5291), Color(0xFF9175B2)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_florist_outlined, color: Colors.white, size: 40),
          SizedBox(height: 14),
          Text(
            'Dobro došli',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Pregledajte termine, klijente, '
            'poruke i rezultate svoga rada.',
            style: TextStyle(
              color: Color(0xFFF0EAF7),
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatistics extends StatelessWidget {
  final TherapistDashboardModel dashboard;

  const _DashboardStatistics({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _DashboardCardData(
        title: 'Današnji termini',
        value: dashboard.todayAppointments.toString(),
        icon: Icons.today_outlined,
      ),
      _DashboardCardData(
        title: 'Nadolazeći termini',
        value: dashboard.upcomingAppointments.toString(),
        icon: Icons.event_available_outlined,
      ),
      _DashboardCardData(
        title: 'Ukupan broj klijenata',
        value: dashboard.totalClients.toString(),
        icon: Icons.people_outline,
      ),
      _DashboardCardData(
        title: 'Novi zahtjevi',
        value: dashboard.newRequests.toString(),
        icon: Icons.pending_actions_outlined,
      ),
      _DashboardCardData(
        title: 'Nepročitane poruke',
        value: dashboard.unreadMessages.toString(),
        icon: Icons.mark_chat_unread_outlined,
      ),
      _DashboardCardData(
        title: 'Prosječna ocjena',
        value: dashboard.averageRating.toStringAsFixed(1),
        icon: Icons.star_outline,
      ),
      _DashboardCardData(
        title: 'Ukupna zarada',
        value: '${dashboard.totalEarnings.toStringAsFixed(2)} KM',
        icon: Icons.payments_outlined,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pregled',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Aktuelni podaci vaše terapeutske prakse.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;

            const spacing = 14.0;

            final width =
                (constraints.maxWidth - ((columnCount - 1) * spacing)) /
                columnCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: cards.map((card) {
                return SizedBox(
                  width: width,
                  child: _DashboardCard(data: card),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final _DashboardCardData data;

  const _DashboardCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7DDF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE5FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(data.icon, color: const Color(0xFF72559A)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: const TextStyle(
                    color: Color(0xFF40334D),
                    fontSize: 22,
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

class _QuickActions extends StatelessWidget {
  final VoidCallback onAppointments;
  final VoidCallback onClients;
  final VoidCallback onProfile;
  final VoidCallback onAvailability;
  final VoidCallback onChat;

  const _QuickActions({
    required this.onAppointments,
    required this.onClients,
    required this.onProfile,
    required this.onAvailability,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        title: 'Moji termini',
        icon: Icons.calendar_month_outlined,
        onTap: onAppointments,
      ),
      _QuickActionData(
        title: 'Klijenti',
        icon: Icons.people_outline,
        onTap: onClients,
      ),
      _QuickActionData(
        title: 'Profil',
        icon: Icons.person_outline,
        onTap: onProfile,
      ),
      _QuickActionData(
        title: 'Dostupnost',
        icon: Icons.schedule_outlined,
        onTap: onAvailability,
      ),
      _QuickActionData(title: 'Chat', icon: Icons.chat_outlined, onTap: onChat),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brze akcije',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Brzo otvorite najčešće korištene sekcije.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth >= 800
                ? 5
                : constraints.maxWidth >= 500
                ? 3
                : 2;

            const spacing = 12.0;

            final width =
                (constraints.maxWidth - ((columnCount - 1) * spacing)) /
                columnCount;

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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7DDF0)),
          ),
          child: Column(
            children: [
              Icon(data.icon, size: 29, color: const Color(0xFF72559A)),
              const SizedBox(height: 10),
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

class _DashboardCardData {
  final String title;
  final String value;
  final IconData icon;

  const _DashboardCardData({
    required this.title,
    required this.value,
    required this.icon,
  });
}

class _QuickActionData {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}
