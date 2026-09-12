import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/admin_status_badge.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_responsive_dialog_content.dart';
import '../../data/models/payment_route_arguments.dart';
import '../viewmodels/payment_management_details_viewmodel.dart';

class PaymentManagementDetailsPage extends StatefulWidget {
  final int paymentId;
  final String paymentType;

  const PaymentManagementDetailsPage({
    super.key,
    required this.paymentId,
    required this.paymentType,
  });

  @override
  State<PaymentManagementDetailsPage> createState() =>
      _PaymentManagementDetailsPageState();
}

class _PaymentManagementDetailsPageState
    extends State<PaymentManagementDetailsPage> {
  final PaymentManagementDetailsViewModel _viewModel =
      AppInjection.createPaymentManagementDetailsViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);

    _viewModel.load(
      paymentType: widget.paymentType,
      paymentId: widget.paymentId,
    );
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

  Future<void> _openReceipt() async {
    await Navigator.of(context).pushNamed(
      AppRouter.paymentReceipt,
      arguments: PaymentRouteArguments(
        paymentId: widget.paymentId,
        paymentType: widget.paymentType,
      ),
    );
  }

  Future<void> _refundPayment() async {
    final payment = _viewModel.payment;

    if (payment == null || !payment.canRefund) {
      return;
    }

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Refund payment'),
          content: AppResponsiveDialogContent(
            preferredWidth: 520,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                minLines: 4,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Refund reason',
                  hintText: 'Explain why the payment is being refunded.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? '';

                  if (normalized.isEmpty) {
                    return 'Refund reason is required.';
                  }

                  if (normalized.length < 5) {
                    return 'Reason must contain at least 5 characters.';
                  }

                  if (normalized.length > 500) {
                    return 'Reason may contain at most 500 characters.';
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
          title: const Text('Confirm Stripe refund'),
          content: const AppResponsiveDialogContent(
            preferredWidth: 500,
            child: Text(
              'This action will send a full refund request to Stripe '
              'for the actually charged amount. The same payment cannot '
              'be refunded twice. Do you want to continue?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('No'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.replay),
              label: const Text('Yes, refund payment'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.refund(
      paymentType: widget.paymentType,
      paymentId: widget.paymentId,
      reason: reason,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund request processed successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading && _viewModel.payment == null) {
      return const Scaffold(
        body: AdminTableLoadingState(message: 'Loading payment details...'),
      );
    }

    final payment = _viewModel.payment;

    if (payment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment details')),
        body: AdminTableErrorState(
          message: _viewModel.error ?? 'Payment could not be loaded.',
          onRetry: () {
            _viewModel.load(
              paymentType: widget.paymentType,
              paymentId: widget.paymentId,
            );
          },
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text('${payment.paymentType} payment #${payment.id}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _viewModel.isLoading
                ? null
                : () {
                    _viewModel.load(
                      paymentType: widget.paymentType,
                      paymentId: widget.paymentId,
                    );
                  },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Open receipt',
            onPressed: _openReceipt,
            icon: const Icon(Icons.receipt_long),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_viewModel.error != null) ...[
                  AppErrorBanner(message: _viewModel.error!),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 18,
                      runSpacing: 14,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${payment.paymentType} payment #${payment.id}',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              payment.purpose,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        AdminStatusBadge(
                          label: _formatStatus(payment.status),
                          tone: _statusTone(payment.status),
                          icon: _statusIcon(payment.status),
                        ),
                        Text(
                          '${payment.amount.toStringAsFixed(2)} '
                          '${payment.currency.toUpperCase()}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _DetailsCard(
                      title: 'Payment',
                      rows: {
                        'Payment ID': payment.id.toString(),
                        'Payment type': payment.paymentType,
                        'Purpose': payment.purpose,
                        'Status': _formatStatus(payment.status),
                        'Amount':
                            '${payment.amount.toStringAsFixed(2)} '
                            '${payment.currency.toUpperCase()}',
                        'Created': formatter.format(
                          payment.createdAtUtc.toLocal(),
                        ),
                        'Paid': payment.paidAtUtc == null
                            ? 'Not paid'
                            : formatter.format(payment.paidAtUtc!.toLocal()),
                      },
                    ),
                    _DetailsCard(
                      title: 'Client',
                      rows: {
                        'Name': payment.clientName,
                        'Email': payment.clientEmail,
                        'Client ID': payment.clientId.toString(),
                        'User ID': payment.clientUserId.toString(),
                      },
                    ),
                    _DetailsCard(
                      title: 'Therapist',
                      rows: {
                        'Name': payment.therapistName,
                        'Email': payment.therapistEmail,
                        'Therapist ID': payment.therapistId.toString(),
                      },
                    ),
                    if (payment.isAppointmentPayment)
                      _DetailsCard(
                        title: 'Appointment',
                        rows: {
                          'Appointment ID':
                              payment.appointmentId?.toString() ?? '-',
                          'Status': payment.appointmentStatus ?? '-',
                          'Type': payment.appointmentType ?? '-',
                          'Start': payment.appointmentStartUtc == null
                              ? '-'
                              : formatter.format(
                                  payment.appointmentStartUtc!.toLocal(),
                                ),
                          'End': payment.appointmentEndUtc == null
                              ? '-'
                              : formatter.format(
                                  payment.appointmentEndUtc!.toLocal(),
                                ),
                          'Marked paid': payment.appointmentIsPaid == true
                              ? 'Yes'
                              : 'No',
                        },
                      ),
                    if (payment.isMembershipPayment)
                      _DetailsCard(
                        title: 'Membership',
                        rows: {
                          'Membership ID':
                              payment.membershipId?.toString() ?? '-',
                          'Plan': payment.membershipPlanType ?? '-',
                          'Total sessions':
                              payment.totalSessions?.toString() ?? '-',
                          'Remaining sessions':
                              payment.remainingSessions?.toString() ?? '-',
                          'Active': payment.membershipIsActive == true
                              ? 'Yes'
                              : 'No',
                          'Expires': payment.membershipExpiresAtUtc == null
                              ? '-'
                              : formatter.format(
                                  payment.membershipExpiresAtUtc!.toLocal(),
                                ),
                        },
                      ),
                    _DetailsCard(
                      title: 'Provider',
                      rows: {
                        'Payment intent': payment.stripePaymentIntentId,
                        'Refund ID': payment.stripeRefundId ?? 'Not available',
                      },
                    ),
                    _DetailsCard(
                      title: 'Refund',
                      rows: {
                        'Reason': payment.refundReason ?? 'Not available',
                        'Requested': payment.refundRequestedAtUtc == null
                            ? 'Not requested'
                            : formatter.format(
                                payment.refundRequestedAtUtc!.toLocal(),
                              ),
                        'Refunded': payment.refundedAtUtc == null
                            ? 'Not refunded'
                            : formatter.format(
                                payment.refundedAtUtc!.toLocal(),
                              ),
                        'Provider failure':
                            payment.refundFailureReason ?? 'None',
                      },
                    ),
                  ],
                ),
                if (!payment.canRefund &&
                    payment.refundUnavailableReason != null &&
                    payment.refundUnavailableReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            payment.refundUnavailableReason!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _openReceipt,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('View receipt'),
                    ),
                    if (payment.canRefund)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.errorContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onErrorContainer,
                        ),
                        onPressed: _viewModel.isRefunding
                            ? null
                            : _refundPayment,
                        icon: _viewModel.isRefunding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.replay),
                        label: Text(
                          _viewModel.isRefunding
                              ? 'Processing refund...'
                              : payment.status.trim().toLowerCase() ==
                                    'refundfailed'
                              ? 'Retry refund'
                              : 'Refund payment',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

AdminStatusTone _statusTone(String status) {
  final normalized = status.trim().toLowerCase();

  if (normalized == 'paid') {
    return AdminStatusTone.success;
  }

  if (normalized == 'refunded') {
    return AdminStatusTone.info;
  }

  if (normalized == 'failed' || normalized == 'refundfailed') {
    return AdminStatusTone.danger;
  }

  return AdminStatusTone.warning;
}

IconData _statusIcon(String status) {
  final normalized = status.trim().toLowerCase();

  if (normalized == 'paid') {
    return Icons.check_circle;
  }

  if (normalized == 'refunded') {
    return Icons.replay;
  }

  if (normalized == 'failed' || normalized == 'refundfailed') {
    return Icons.error_outline;
  }

  return Icons.schedule;
}

String _formatStatus(String value) {
  switch (value) {
    case 'RefundPending':
      return 'Refund pending';
    case 'RefundFailed':
      return 'Refund failed';
    default:
      return value;
  }
}

class _DetailsCard extends StatelessWidget {
  final String title;
  final Map<String, String> rows;

  const _DetailsCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
                        width: 120,
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
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
