import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/admin_status_badge.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_error_panel.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/app_responsive_dialog_content.dart';
import '../../data/models/admin_appointment_details_model.dart';
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
          content: AppResponsiveDialogContent(
            preferredWidth: 520,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                minLines: 4,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Administrative reason',
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
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue'),
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
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Yes, cancel appointment'),
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
      return const Scaffold(
        body: AppLoadingState(message: 'Loading appointment details...'),
      );
    }

    final appointment = _viewModel.appointment;

    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Appointment details')),
        body: AppErrorPanel(
          message: _viewModel.error ?? 'Appointment could not be loaded.',
          onRetry: () {
            _viewModel.load(widget.appointmentId);
          },
          retryLabel: 'Try again',
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
                _AppointmentHero(appointment: appointment),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth >= 1040
                        ? (constraints.maxWidth - 32) / 3
                        : constraints.maxWidth >= 700
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _DetailsCard(
                          width: cardWidth,
                          title: 'Client',
                          rows: {
                            'Name': appointment.clientName,
                            'Email': appointment.clientEmail,
                            'Client ID': appointment.clientId.toString(),
                          },
                        ),
                        _DetailsCard(
                          width: cardWidth,
                          title: 'Therapist',
                          rows: {
                            'Name': appointment.therapistName,
                            'Email': appointment.therapistEmail,
                            'Therapist ID': appointment.therapistId.toString(),
                          },
                        ),
                        _DetailsCard(
                          width: cardWidth,
                          title: 'Appointment',
                          rows: {
                            'Status': appointment.status,
                            'Type': appointment.type,
                            'Start': formatter.format(
                              appointment.startUtc.toLocal(),
                            ),
                            'End': formatter.format(
                              appointment.endUtc.toLocal(),
                            ),
                            'Location': appointment.location ?? 'Not set',
                            'Meeting link':
                                appointment.meetingLink ?? 'Not set',
                          },
                        ),
                        _DetailsCard(
                          width: cardWidth,
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
                          width: cardWidth,
                          title: 'Membership',
                          rows: {
                            'Used': appointment.hasMembershipUsage
                                ? 'Yes'
                                : 'No',
                            'Usage status':
                                appointment.membershipUsageStatus ?? 'Not used',
                          },
                        ),
                      ],
                    );
                  },
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
                  AppErrorBanner(message: _viewModel.error!),
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

  final double width;

  const _DetailsCard({
    required this.title,
    required this.rows,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
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

class _AppointmentHero extends StatelessWidget {
  final AdminAppointmentDetailsModel appointment;

  const _AppointmentHero({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;

            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appointment #${appointment.id}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${appointment.clientName} with ${appointment.therapistName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AdminStatusBadge(
                      label: _appointmentStatusLabel(appointment.status),
                      tone: _appointmentStatusTone(appointment.status),
                    ),
                    AdminStatusBadge(
                      label: _appointmentTypeLabel(appointment.type),
                      tone: AdminStatusTone.info,
                    ),
                    AdminStatusBadge(
                      label: appointment.isPaid ? 'Paid' : 'Unpaid',
                      tone: appointment.isPaid
                          ? AdminStatusTone.success
                          : AdminStatusTone.warning,
                      icon: appointment.isPaid
                          ? Icons.check_circle_outline
                          : Icons.schedule_outlined,
                    ),
                  ],
                ),
              ],
            );

            final schedule = Column(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Text(
                  'Starts',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatter.format(appointment.startUtc.toLocal()),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [title, const SizedBox(height: 18), schedule],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
                const SizedBox(width: 20),
                schedule,
              ],
            );
          },
        ),
      ),
    );
  }
}

String _appointmentStatusLabel(String status) {
  switch (status) {
    case '0':
      return 'Pending';
    case '1':
      return 'Accepted';
    case '2':
      return 'Rejected';
    case '3':
      return 'Completed';
    case '4':
      return 'Cancelled';
    default:
      return status;
  }
}

String _appointmentTypeLabel(String type) {
  switch (type) {
    case '1':
      return 'Online';
    case '2':
      return 'In person';
    default:
      return type;
  }
}

AdminStatusTone _appointmentStatusTone(String status) {
  switch (status) {
    case '1':
    case '3':
    case 'Accepted':
    case 'Completed':
      return AdminStatusTone.success;
    case '0':
    case 'Pending':
      return AdminStatusTone.warning;
    case '2':
    case '4':
    case 'Rejected':
    case 'Cancelled':
      return AdminStatusTone.danger;
    default:
      return AdminStatusTone.neutral;
  }
}
