import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/appointment_model.dart';
import '../viewmodels/appointment_details_viewmodel.dart';

class AppointmentDetailsPage extends StatefulWidget {
  final AppointmentModel appointment;

  const AppointmentDetailsPage({super.key, required this.appointment});

  @override
  State<AppointmentDetailsPage> createState() => _AppointmentDetailsPageState();
}

class _AppointmentDetailsPageState extends State<AppointmentDetailsPage> {
  late final AppointmentDetailsViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createAppointmentDetailsViewModel(
      widget.appointment,
    );

    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _joinSession() async {
    final appointment = _viewModel.currentAppointment;

    final link = appointment.meetingLink;

    if (link == null || link.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting link is not available yet.')),
      );

      return;
    }

    final uri = Uri.tryParse(link.trim());

    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meeting link is invalid.')));

      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open meeting link.')),
      );
    }
  }

  Future<void> _showCancellationDialog() async {
    final reasonController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel appointment'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: reasonController,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Cancellation reason',
                hintText: 'Explain why you are cancelling the appointment.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                final reason = value?.trim() ?? '';

                if (reason.isEmpty) {
                  return 'Cancellation reason is required.';
                }

                if (reason.length < 5) {
                  return 'Reason must contain at least 5 characters.';
                }

                return null;
              },
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

                Navigator.of(dialogContext).pop(reasonController.text.trim());
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm cancellation'),
          content: const Text(
            'Are you sure you want to cancel this appointment? '
            'If it has already been paid, the refund will be initiated automatically.',
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
              child: const Text('Yes, cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.cancelAppointment(reason);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Appointment cancelled successfully. '
            'Any eligible refund has been initiated.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = _viewModel.currentAppointment;

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    final normalizedStatus = appointment.status.trim().toLowerCase();

    final canCancel =
        normalizedStatus == 'pending' || normalizedStatus == 'accepted';

    final canJoinSession =
        appointment.type.trim().toLowerCase() == 'online' &&
        appointment.meetingLink != null &&
        appointment.meetingLink!.trim().isNotEmpty &&
        normalizedStatus == 'accepted';

    final canReview = normalizedStatus == 'completed';

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
              onPressed: canJoinSession ? _joinSession : null,
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
              onPressed: canCancel
                  ? () {
                      Navigator.of(context).pushNamed(
                        AppRouter.useMembership,
                        arguments: appointment,
                      );
                    }
                  : null,
              icon: const Icon(Icons.card_membership),
              label: const Text('Use membership'),
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

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: canCancel && !_viewModel.isLoading
                  ? _showCancellationDialog
                  : null,
              icon: _viewModel.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: Text(
                canCancel ? 'Cancel appointment' : 'Cancellation unavailable',
              ),
            ),

            if (_viewModel.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _viewModel.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    );
  }
}
