import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/di/injection.dart';
import '../../data/models/appointment_model.dart';
import '../viewmodels/my_appointments_viewmodel.dart';

class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> {
  final MyAppointmentsViewModel _viewModel =
      AppInjection.createMyAppointmentsViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onChanged);
    _viewModel.loadAppointments();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    await _viewModel.loadAppointments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My appointments')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _viewModel.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_viewModel.appointments.isEmpty) {
      return const Center(child: Text('You do not have appointments yet.'));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _viewModel.appointments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final appointment = _viewModel.appointments[index];

          return InkWell(
            onTap: () {
              Navigator.of(
                context,
              ).pushNamed(AppRouter.appointmentDetails, arguments: appointment);
            },
            child: _AppointmentCard(appointment: appointment),
          );
        },
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy. HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appointment.therapistName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.calendar_month, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateFormat.format(appointment.startUtc.toLocal()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Text(
                  appointment.status,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.video_call, size: 18),
                const SizedBox(width: 8),
                Text(appointment.type),
              ],
            ),

            if (appointment.meetingLink != null &&
                appointment.meetingLink!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                appointment.meetingLink!,
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            ],

            if (appointment.location != null &&
                appointment.location!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(appointment.location!),
            ],
          ],
        ),
      ),
    );
  }
}
