import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../data/models/payment_receipt_model.dart';
import '../viewmodels/payment_list_viewmodel.dart';

class PaymentReceiptPage extends StatefulWidget {
  final int paymentId;

  const PaymentReceiptPage({super.key, required this.paymentId});

  @override
  State<PaymentReceiptPage> createState() => _PaymentReceiptPageState();
}

class _PaymentReceiptPageState extends State<PaymentReceiptPage> {
  final PaymentListViewModel _viewModel = AppInjection.createPaymentViewModel();

  PaymentReceiptModel? _receipt;

  bool _isLoading = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _viewModel.loadReceipt(widget.paymentId);

      if (!mounted) {
        return;
      }

      setState(() {
        _receipt = result;
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = exception.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction details')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final receipt = _receipt;

    if (receipt == null) {
      return const Center(
        child: Text('Transaction details are not available.'),
      );
    }

    final date = DateFormat('dd.MM.yyyy. HH:mm');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.receipt_long, size: 65),

        const SizedBox(height: 14),

        Text(
          receipt.invoiceNumber,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),

        const SizedBox(height: 20),

        _DetailRow(label: 'Purpose', value: receipt.purpose),

        _DetailRow(label: 'Client', value: receipt.clientName),

        _DetailRow(label: 'Therapist', value: receipt.therapistName),

        _DetailRow(
          label: 'Amount',
          value:
              '${receipt.amount.toStringAsFixed(2)} '
              '${receipt.currency}',
        ),

        _DetailRow(label: 'Status', value: receipt.status),

        _DetailRow(
          label: 'Payment date',
          value: date.format(receipt.paymentDateUtc.toLocal()),
        ),

        _DetailRow(
          label: 'Appointment',
          value:
              '${date.format(receipt.appointmentStartUtc.toLocal())} - '
              '${date.format(receipt.appointmentEndUtc.toLocal())}',
        ),

        _DetailRow(
          label: 'Stripe reference',
          value: receipt.stripePaymentIntentId,
        ),

        if (receipt.hasRefundInformation) ...[
          const SizedBox(height: 18),

          const Text(
            'Refund information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          if (receipt.refundReason != null)
            _DetailRow(label: 'Reason', value: receipt.refundReason!),

          if (receipt.refundRequestedAtUtc != null)
            _DetailRow(
              label: 'Requested',
              value: date.format(receipt.refundRequestedAtUtc!.toLocal()),
            ),

          if (receipt.refundedAtUtc != null)
            _DetailRow(
              label: 'Refunded',
              value: date.format(receipt.refundedAtUtc!.toLocal()),
            ),

          if (receipt.stripeRefundId != null)
            _DetailRow(
              label: 'Stripe refund reference',
              value: receipt.stripeRefundId!,
            ),

          if (receipt.refundFailureReason != null)
            _DetailRow(
              label: 'Refund error',
              value: receipt.refundFailureReason!,
            ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(title: Text(label), subtitle: Text(value)),
    );
  }
}
