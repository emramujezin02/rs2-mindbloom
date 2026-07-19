import 'package:flutter/material.dart';
import 'package:mindbloom_mobile/app/di/injection.dart';

import '../../../../app/router/app_router.dart';
import '../../data/models/appointment_model.dart';
import '../../data/models/therapist_appointment_status.dart';
import '../viewmodels/therapist_appointments_viewmodel.dart';

class TherapistAppointmentDetailsPage extends StatefulWidget {
  final AppointmentModel appointment;

  const TherapistAppointmentDetailsPage({super.key, required this.appointment});

  @override
  State<TherapistAppointmentDetailsPage> createState() =>
      _TherapistAppointmentDetailsPageState();
}

class _TherapistAppointmentDetailsPageState
    extends State<TherapistAppointmentDetailsPage> {
  late final TherapistAppointmentsViewModel viewModel;

  late AppointmentModel appointment;

  @override
  void initState() {
    super.initState();

    appointment = widget.appointment;

    viewModel = AppInjection.createTherapistAppointmentsViewModel();

    viewModel.addListener(_onViewModelChanged);
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

  Future<void> _changeStatus(TherapistAppointmentStatus status) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${status.label} appointment?'),
          content: Text(
            'Are you sure you want to mark '
            'appointment #${appointment.id} as '
            '${status.label.toLowerCase()}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await viewModel.updateStatus(
      appointment: appointment,
      status: status,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      setState(() {
        appointment = appointment.copyWith(status: status.label);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Appointment marked as '
            '${status.label.toLowerCase()}.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.errorMessage ?? 'Status could not be updated.',
          ),
        ),
      );
    }
  }

  void _openChat() {
    Navigator.of(
      context,
    ).pushNamed(AppRouter.chatDetails, arguments: appointment.id);
  }

  @override
  Widget build(BuildContext context) {
    final status = appointment.status.trim().toLowerCase();

    final canAccept = status == 'pending';
    final canReject = status == 'pending';

    final canComplete = status == 'accepted';

    final canCancel = status == 'pending' || status == 'accepted';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Appointment details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderCard(appointment: appointment),
                const SizedBox(height: 18),
                _DetailsCard(appointment: appointment),
                if (appointment.meetingLink != null &&
                    appointment.meetingLink!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _TextInformationCard(
                    icon: Icons.video_call_outlined,
                    title: 'Meeting link',
                    value: appointment.meetingLink!,
                  ),
                ],
                if (appointment.location != null &&
                    appointment.location!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _TextInformationCard(
                    icon: Icons.location_on_outlined,
                    title: 'Location',
                    value: appointment.location!,
                  ),
                ],
                const SizedBox(height: 22),
                if (viewModel.isUpdatingStatus)
                  const Center(child: CircularProgressIndicator())
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (canAccept)
                        FilledButton.icon(
                          onPressed: () {
                            _changeStatus(TherapistAppointmentStatus.accepted);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Accept'),
                        ),
                      if (canReject)
                        OutlinedButton.icon(
                          onPressed: () {
                            _changeStatus(TherapistAppointmentStatus.rejected);
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                        ),
                      if (canComplete)
                        FilledButton.icon(
                          onPressed: () {
                            _changeStatus(TherapistAppointmentStatus.completed);
                          },
                          icon: const Icon(Icons.task_alt),
                          label: const Text('Complete'),
                        ),
                      if (canCancel)
                        OutlinedButton.icon(
                          onPressed: () {
                            _changeStatus(TherapistAppointmentStatus.cancelled);
                          },
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel'),
                        ),
                      OutlinedButton.icon(
                        onPressed: _openChat,
                        icon: const Icon(Icons.chat),
                        label: const Text('Open chat'),
                      ),
                    ],
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final AppointmentModel appointment;

  const _HeaderCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5291), Color(0xFF9175B2)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person_outline,
              size: 39,
              color: Color(0xFF72559A),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            appointment.clientName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Appointment #${appointment.id}',
            style: const TextStyle(color: Color(0xFFEFE9F6)),
          ),
          const SizedBox(height: 13),
          _DetailsStatusBadge(status: appointment.status),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final AppointmentModel appointment;

  const _DetailsCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final start = appointment.startUtc.toLocal();

    final end = appointment.endUtc.toLocal();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5DBEF)),
      ),
      child: Column(
        children: [
          _DetailsRow(label: 'Date', value: _formatDate(start)),
          const Divider(height: 27),
          _DetailsRow(label: 'Start time', value: _formatTime(start)),
          const Divider(height: 27),
          _DetailsRow(label: 'End time', value: _formatTime(end)),
          const Divider(height: 27),
          _DetailsRow(
            label: 'Type',
            value: appointment.type.isEmpty
                ? 'Not specified'
                : appointment.type,
          ),
          const Divider(height: 27),
          _DetailsRow(label: 'Status', value: appointment.status),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}.';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailsRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF756D79))),
        ),
        const SizedBox(width: 15),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF40334D),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TextInformationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _TextInformationCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE5DBEF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF72559A)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF40334D),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                SelectableText(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsStatusBadge extends StatelessWidget {
  final String status;

  const _DetailsStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status.isEmpty ? 'Pending' : status,
        style: const TextStyle(
          color: Color(0xFF674B8B),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
