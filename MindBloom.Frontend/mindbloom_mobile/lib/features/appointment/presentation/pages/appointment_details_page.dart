import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_router.dart';
import '../../data/models/appointment_model.dart';

class AppointmentDetailsPage extends StatelessWidget {
  final AppointmentModel appointment;

  const AppointmentDetailsPage({super.key, required this.appointment});

  Future<void> _joinSession(BuildContext context) async {
    final link = appointment.meetingLink;

    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting link is not available yet.')),
      );
      return;
    }

    final uri = Uri.parse(link);

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open meeting link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    final canJoinSession =
        appointment.type == 'Online' &&
        appointment.meetingLink != null &&
        appointment.meetingLink!.isNotEmpty;

    final canReview = appointment.status.toLowerCase() == 'completed';

    return Scaffold(
      appBar: AppBar(title: const Text('Appointment details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.calendar_month, size: 80),

            const SizedBox(height: 20),

            Text(
              appointment.therapistName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _RowItem(label: 'Status', value: appointment.status),
                    const Divider(),
                    _RowItem(label: 'Type', value: appointment.type),
                    const Divider(),
                    _RowItem(
                      label: 'Start',
                      value: formatter.format(appointment.startUtc.toLocal()),
                    ),
                    const Divider(),
                    _RowItem(
                      label: 'End',
                      value: formatter.format(appointment.endUtc.toLocal()),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (appointment.meetingLink != null &&
                appointment.meetingLink!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Meeting link',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(appointment.meetingLink!),
                    ],
                  ),
                ),
              ),

            if (appointment.location != null &&
                appointment.location!.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(appointment.location!),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: canJoinSession ? () => _joinSession(context) : null,
              icon: const Icon(Icons.video_call),
              label: Text(
                canJoinSession ? 'Join session' : 'Join session unavailable',
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.myPayments);
              },
              icon: const Icon(Icons.payment),
              label: const Text('Payment history'),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: canReview
                  ? () {
                      Navigator.of(context).pushNamed(
                        AppRouter.createReview,
                        arguments: appointment,
                      );
                    }
                  : null,
              icon: const Icon(Icons.star),
              label: Text(
                canReview
                    ? 'Leave review'
                    : 'Review available after completion',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final String label;
  final String value;

  const _RowItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Text(value),
      ],
    );
  }
}
