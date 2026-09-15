import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/admin_status_badge.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../viewmodels/payment_receipt_viewmodel.dart';

class PaymentReceiptPage extends StatefulWidget {
  final int paymentId;
  final String paymentType;

  const PaymentReceiptPage({
    super.key,
    required this.paymentId,
    required this.paymentType,
  });
  @override
  State<PaymentReceiptPage> createState() => _PaymentReceiptPageState();
}

class _PaymentReceiptPageState extends State<PaymentReceiptPage> {
  final PaymentReceiptViewModel _viewModel =
      AppInjection.createPaymentReceiptViewModel();

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

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading) {
      return const Scaffold(
        body: AdminTableLoadingState(message: 'Loading payment receipt...'),
      );
    }

    final receipt = _viewModel.receipt;

    if (receipt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receipt')),
        body: AdminTableErrorState(
          message: _viewModel.error ?? 'Receipt could not be loaded.',
          onRetry: () {
            _viewModel.load(
              paymentType: widget.paymentType,
              paymentId: widget.paymentId,
            );
          },
        ),
      );
    }

    final dateFormatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Scaffold(
      appBar: AppBar(title: Text(receipt.invoiceNumber)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.spa,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'MindBloom',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Payment receipt',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: AdminStatusBadge(
                        label: receipt.status,
                        tone: _statusTone(receipt.status),
                        icon: _statusIcon(receipt.status),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _ReceiptRow(
                      label: 'Invoice number',
                      value: receipt.invoiceNumber,
                    ),
                    _ReceiptRow(
                      label: 'Payment ID',
                      value: receipt.paymentId.toString(),
                    ),
                    if (receipt.appointmentId != null)
                      _ReceiptRow(
                        label: 'Appointment ID',
                        value: receipt.appointmentId.toString(),
                      ),

                    if (receipt.membershipId != null)
                      _ReceiptRow(
                        label: 'Membership ID',
                        value: receipt.membershipId.toString(),
                      ),
                    const Divider(height: 32),
                    _ReceiptRow(label: 'Client', value: receipt.clientName),
                    _ReceiptRow(
                      label: 'Client email',
                      value: receipt.clientEmail,
                    ),
                    _ReceiptRow(
                      label: 'Therapist',
                      value: receipt.therapistName,
                    ),
                    const Divider(height: 32),
                    _ReceiptRow(label: 'Status', value: receipt.status),
                    _ReceiptRow(
                      label: 'Amount',
                      value:
                          '${receipt.amount.toStringAsFixed(2)} '
                          '${receipt.currency}',
                    ),
                    _ReceiptRow(
                      label: 'Payment date',
                      value: dateFormatter.format(
                        receipt.paymentDateUtc.toLocal(),
                      ),
                    ),
                    if (receipt.appointmentStartUtc != null)
                      _ReceiptRow(
                        label: 'Appointment start',
                        value: dateFormatter.format(
                          receipt.appointmentStartUtc!.toLocal(),
                        ),
                      ),

                    if (receipt.appointmentEndUtc != null)
                      _ReceiptRow(
                        label: 'Appointment end',
                        value: dateFormatter.format(
                          receipt.appointmentEndUtc!.toLocal(),
                        ),
                      ),
                    const Divider(height: 32),
                    _ReceiptRow(
                      label: 'Stripe PaymentIntent',
                      value: receipt.stripePaymentIntentId,
                    ),
                    if (receipt.stripeRefundId != null)
                      _ReceiptRow(
                        label: 'Stripe refund ID',
                        value: receipt.stripeRefundId!,
                      ),
                    if (receipt.refundReason != null)
                      _ReceiptRow(
                        label: 'Refund reason',
                        value: receipt.refundReason!,
                      ),
                    if (receipt.refundedAtUtc != null)
                      _ReceiptRow(
                        label: 'Refunded at',
                        value: dateFormatter.format(
                          receipt.refundedAtUtc!.toLocal(),
                        ),
                      ),

                    _ReceiptRow(
                      label: 'Payment type',
                      value: receipt.paymentType,
                    ),
                    _ReceiptRow(label: 'Purpose', value: receipt.purpose),
                    const SizedBox(height: 24),
                    const Text(
                      'This receipt was generated by '
                      'the MindBloom administration system.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;

  final String value;

  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;

        final labelWidget = Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        );

        final valueWidget = SelectableText(
          value,
          textAlign: compact ? TextAlign.left : TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w600),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelWidget,
                    const SizedBox(height: 4),
                    valueWidget,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 190, child: labelWidget),
                    Expanded(child: valueWidget),
                  ],
                ),
        );
      },
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
