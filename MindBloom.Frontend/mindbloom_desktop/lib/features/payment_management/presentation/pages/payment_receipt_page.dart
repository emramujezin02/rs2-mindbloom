import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../viewmodels/payment_receipt_viewmodel.dart';

class PaymentReceiptPage extends StatefulWidget {
  final int paymentId;

  const PaymentReceiptPage({super.key, required this.paymentId});

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

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final receipt = _viewModel.receipt;

    if (receipt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receipt')),
        body: Center(
          child: Text(_viewModel.error ?? 'Receipt could not be loaded.'),
        ),
      );
    }

    final dateFormatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Scaffold(
      appBar: AppBar(title: Text(receipt.invoiceNumber)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.spa, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'MindBloom',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Payment receipt', textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    _ReceiptRow(
                      label: 'Invoice number',
                      value: receipt.invoiceNumber,
                    ),
                    _ReceiptRow(
                      label: 'Payment ID',
                      value: receipt.paymentId.toString(),
                    ),
                    _ReceiptRow(
                      label: 'Appointment ID',
                      value: receipt.appointmentId.toString(),
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
                    _ReceiptRow(
                      label: 'Appointment start',
                      value: dateFormatter.format(
                        receipt.appointmentStartUtc.toLocal(),
                      ),
                    ),
                    _ReceiptRow(
                      label: 'Appointment end',
                      value: dateFormatter.format(
                        receipt.appointmentEndUtc.toLocal(),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 190,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
