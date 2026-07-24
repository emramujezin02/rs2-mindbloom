import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
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
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _viewModel.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _viewModel.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  _RecommendationCard(
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushNamed(AppRouter.recommendations);
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
                    value: _viewModel.dashboard!.totalAppointments.toString(),
                  ),
                  _DashboardCard(
                    icon: Icons.check_circle,
                    title: 'Completed appointments',
                    value: _viewModel.dashboard!.completedAppointments
                        .toString(),
                  ),
                  _DashboardCard(
                    icon: Icons.schedule,
                    title: 'Pending appointments',
                    value: _viewModel.dashboard!.pendingAppointments.toString(),
                  ),
                  _DashboardCard(
                    icon: Icons.cancel,
                    title: 'Cancelled appointments',
                    value: _viewModel.dashboard!.cancelledAppointments
                        .toString(),
                  ),
                  _DashboardCard(
                    icon: Icons.psychology,
                    title: 'Therapists visited',
                    value: _viewModel.dashboard!.totalTherapistsVisited
                        .toString(),
                  ),
                  _DashboardCard(
                    icon: Icons.payments,
                    title: 'Total spent',
                    value:
                        '${_viewModel.dashboard!.totalSpent.toStringAsFixed(2)} KM',
                  ),
                  _DashboardCard(
                    icon: Icons.history,
                    title: 'Last appointment',
                    value: _viewModel.dashboard!.lastAppointmentDate == null
                        ? 'No previous appointments'
                        : formatter.format(
                            _viewModel.dashboard!.lastAppointmentDate!
                                .toLocal(),
                          ),
                  ),
                  _DashboardCard(
                    icon: Icons.event_available,
                    title: 'Next appointment',
                    value: _viewModel.dashboard!.nextAppointmentDate == null
                        ? 'No upcoming appointments'
                        : formatter.format(
                            _viewModel.dashboard!.nextAppointmentDate!
                                .toLocal(),
                          ),
                  ),
                ],
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
