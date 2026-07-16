import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../viewmodels/payment_management_details_viewmodel.dart';

class PaymentManagementDetailsPage extends StatefulWidget {
  final int paymentId;

  const PaymentManagementDetailsPage({super.key, required this.paymentId});

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

    _viewModel.load(widget.paymentId);
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

  Future<void> _refundPayment() async {
    final controller = TextEditingController();

    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Refund payment'),
          content: SizedBox(
            width: 500,
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
                  final reason = value?.trim() ?? '';

                  if (reason.isEmpty) {
                    return 'Refund reason is required.';
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
          title: const Text('Confirm Stripe refund'),
          content: const Text(
            'This action will send a refund request '
            'to Stripe for the actually charged amount. '
            'The same payment cannot be refunded twice. '
            'Do you want to continue?',
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
    if (_viewModel.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final payment = _viewModel.payment;

    if (payment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _viewModel.error ?? 'Payment could not be loaded.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text('Payment #${payment.id}'),
        actions: [
          IconButton(
            tooltip: 'Open receipt',
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamed(AppRouter.paymentReceipt, arguments: payment.id);
            },
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
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _DetailsCard(
                      title: 'Payment',
                      rows: {
                        'Payment ID': payment.id.toString(),
                        'Status': payment.status,
                        'Amount':
                            '${payment.amount.toStringAsFixed(2)} '
                            '${payment.currency}',
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
                    _DetailsCard(
                      title: 'Appointment',
                      rows: {
                        'Appointment ID': payment.appointmentId.toString(),
                        'Status': payment.appointmentStatus,
                        'Type': payment.appointmentType,
                        'Start': formatter.format(
                          payment.appointmentStartUtc.toLocal(),
                        ),
                        'End': formatter.format(
                          payment.appointmentEndUtc.toLocal(),
                        ),
                        'Marked paid': payment.appointmentIsPaid ? 'Yes' : 'No',
                      },
                    ),
                    _DetailsCard(
                      title: 'Stripe',
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
                        'Failure': payment.refundFailureReason ?? 'None',
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          AppRouter.paymentReceipt,
                          arguments: payment.id,
                        );
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('View receipt'),
                    ),
                    const SizedBox(width: 12),
                    if (payment.canRefund)
                      ElevatedButton.icon(
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
                              : payment.status == 'RefundFailed'
                              ? 'Retry refund'
                              : 'Refund payment',
                        ),
                      ),
                  ],
                ),
                if (!payment.canRefund) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Refund unavailable'),
                      subtitle: Text(
                        payment.status == 'Refunded'
                            ? 'This payment has already been refunded.'
                            : payment.status == 'RefundPending'
                            ? 'A refund is already being processed.'
                            : 'Only a paid payment may be refunded.',
                      ),
                    ),
                  ),
                ],
                if (_viewModel.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _viewModel.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
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
                        width: 110,
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
