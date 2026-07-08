import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
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
