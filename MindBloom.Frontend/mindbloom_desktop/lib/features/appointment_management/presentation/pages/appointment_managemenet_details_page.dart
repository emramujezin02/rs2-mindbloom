import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../viewmodels/appointment_management_details_viewmodel.dart';

class AppointmentManagementDetailsPage extends StatefulWidget {
  final int appointmentId;

  const AppointmentManagementDetailsPage({
    super.key,
    required this.appointmentId,
  });

  @override
  State<AppointmentManagementDetailsPage> createState() =>
      _AppointmentManagementDetailsPageState();
}

class _AppointmentManagementDetailsPageState
    extends State<AppointmentManagementDetailsPage> {
  final AppointmentManagementDetailsViewModel _viewModel =
      AppInjection.createAppointmentManagementDetailsViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);

    _viewModel.load(widget.appointmentId);
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

  Future<void> _cancelAppointment() async {
    final controller = TextEditingController();

    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel appointment'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                minLines: 4,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Administrative reason',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final reason = value?.trim() ?? '';

                  if (reason.isEmpty) {
                    return 'Reason is required.';
                  }

                  if (reason.length < 5) {
                    return 'Reason must contain at least 5 characters.';
                  }

                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm cancellation'),
          content: const Text(
            'This will cancel the appointment. '
            'A paid Stripe payment will be refunded '
            'and a reserved membership session will '
            'be restored. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Yes, cancel appointment'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.cancel(
      appointmentId: widget.appointmentId,
      reason: reason,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final appointment = _viewModel.appointment;

    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Appointment details')),
        body: Center(
          child: Text(_viewModel.error ?? 'Appointment could not be loaded.'),
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Scaffold(
      appBar: AppBar(title: Text('Appointment #${appointment.id}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _DetailsCard(
                      title: 'Client',
                      rows: {
                        'Name': appointment.clientName,
                        'Email': appointment.clientEmail,
                        'Client ID': appointment.clientId.toString(),
                      },
                    ),
                    _DetailsCard(
                      title: 'Therapist',
                      rows: {
                        'Name': appointment.therapistName,
                        'Email': appointment.therapistEmail,
                        'Therapist ID': appointment.therapistId.toString(),
                      },
                    ),
                    _DetailsCard(
                      title: 'Appointment',
                      rows: {
                        'Status': appointment.status,
                        'Type': appointment.type,
                        'Start': formatter.format(
                          appointment.startUtc.toLocal(),
                        ),
                        'End': formatter.format(appointment.endUtc.toLocal()),
                        'Location': appointment.location ?? 'Not set',
                        'Meeting link': appointment.meetingLink ?? 'Not set',
                      },
                    ),
                    _DetailsCard(
                      title: 'Payment',
                      rows: {
                        'Paid': appointment.isPaid ? 'Yes' : 'No',
                        'Status': appointment.paymentStatus ?? 'No payment',
                        'Amount': appointment.paymentAmount == null
                            ? 'Not available'
                            : appointment.paymentAmount!.toStringAsFixed(2),
                        'Refund reason':
                            appointment.refundReason ?? 'Not available',
                      },
                    ),
                    _DetailsCard(
                      title: 'Membership',
                      rows: {
                        'Used': appointment.hasMembershipUsage ? 'Yes' : 'No',
                        'Usage status':
                            appointment.membershipUsageStatus ?? 'Not used',
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (appointment.canAdminCancel)
                  ElevatedButton.icon(
                    onPressed: _viewModel.isCancelling
                        ? null
                        : _cancelAppointment,
                    icon: _viewModel.isCancelling
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel),
                    label: const Text('Cancel appointment'),
                  ),
                if (_viewModel.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _viewModel.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 28),
                const Text(
                  'Status audit history',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (appointment.auditHistory.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No status audit records are available.'),
                    ),
                  )
                else
                  ...appointment.auditHistory.map(
                    (audit) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(
                          '${audit.previousStatus ?? "None"} '
                          '→ ${audit.newStatus}',
                        ),
                        subtitle: Text(
                          '${audit.action}\n'
                          '${audit.reason ?? "No reason"}\n'
                          '${audit.changedByUserName} '
                          '(${audit.changedByUserEmail})',
                        ),
                        trailing: Text(
                          formatter.format(audit.changedAtUtc.toLocal()),
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final String title;

  final Map<String, String> rows;

  const _DetailsCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 24),
              ...rows.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 105,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(child: SelectableText(entry.value)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
