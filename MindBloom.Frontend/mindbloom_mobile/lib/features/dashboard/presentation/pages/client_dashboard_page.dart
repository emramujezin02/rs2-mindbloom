import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../viewmodels/client_dashboard_viewmodel.dart';

class ClientDashboardPage extends StatefulWidget {
  const ClientDashboardPage({super.key});

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
  final ClientDashboardViewModel _viewModel =
      AppInjection.createClientDashboardViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);
    _viewModel.loadDashboard();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _viewModel.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('My dashboard')),
      body: _buildBody(formatter),
    );
  }

  Widget _buildBody(DateFormat formatter) {
    final dashboard = _viewModel.dashboard;

    if (_viewModel.isLoading && dashboard == null) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading dashboard...',
        skeletonItemCount: 6,
      );
    }

    if (_viewModel.error != null && dashboard == null) {
      return AppErrorWidget(
        title: 'Dashboard could not be loaded',
        error: _viewModel.error,
        onRetry: _viewModel.refresh,
      );
    }

    if (dashboard == null) {
      return RefreshIndicator(
        onRefresh: _viewModel.refresh,
        child: const AppEmptyStateWidget(
          title: 'Dashboard unavailable',
          message: 'Dashboard data is currently unavailable.',
          icon: Icons.dashboard_outlined,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Dashboard could not be refreshed',
              error: _viewModel.error,
              onRetry: _viewModel.refresh,
              margin: const EdgeInsets.only(bottom: 12),
            ),
          _RecommendationCard(
            onTap: () {
              Navigator.of(context).pushNamed(AppRouter.recommendations);
            },
          ),
          _PrivateJournalNavigationCard(
            onTap: () {
              Navigator.of(context).pushNamed(AppRouter.privateJournal);
            },
          ),
          _AnalyticsNavigationCard(
            onTap: () {
              Navigator.of(
                context,
              ).pushNamed(AppRouter.clientEmotionalAnalytics);
            },
          ),
          _DashboardCard(
            icon: Icons.calendar_month,
            title: 'Total appointments',
            value: dashboard.totalAppointments.toString(),
          ),
          _DashboardCard(
            icon: Icons.check_circle,
            title: 'Completed appointments',
            value: dashboard.completedAppointments.toString(),
          ),
          _DashboardCard(
            icon: Icons.schedule,
            title: 'Pending appointments',
            value: dashboard.pendingAppointments.toString(),
          ),
          _DashboardCard(
            icon: Icons.cancel,
            title: 'Cancelled appointments',
            value: dashboard.cancelledAppointments.toString(),
          ),
          _DashboardCard(
            icon: Icons.psychology,
            title: 'Therapists visited',
            value: dashboard.totalTherapistsVisited.toString(),
          ),
          _DashboardCard(
            icon: Icons.payments,
            title: 'Total spent',
            value: '${dashboard.totalSpent.toStringAsFixed(2)} KM',
          ),
          _DashboardCard(
            icon: Icons.history,
            title: 'Last appointment',
            value: dashboard.lastAppointmentDate == null
                ? 'No previous appointments'
                : formatter.format(dashboard.lastAppointmentDate!.toLocal()),
          ),
          _DashboardCard(
            icon: Icons.event_available,
            title: 'Next appointment',
            value: dashboard.nextAppointmentDate == null
                ? 'No upcoming appointments'
                : formatter.format(dashboard.nextAppointmentDate!.toLocal()),
          ),
        ],
      ),
    );
  }
}

class _PrivateJournalNavigationCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PrivateJournalNavigationCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                child: Icon(Icons.menu_book_outlined, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Private journal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('Write and manage private journal entries.'),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final VoidCallback onTap;

  const _RecommendationCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended therapists',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('View therapists recommended specifically for you.'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _AnalyticsNavigationCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AnalyticsNavigationCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(radius: 26, child: Icon(Icons.insights, size: 28)),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My emotional patterns',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'View mood trends and your most frequently recorded emotions.',
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
