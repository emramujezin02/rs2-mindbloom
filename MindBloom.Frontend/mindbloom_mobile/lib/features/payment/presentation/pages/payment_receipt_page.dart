import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../viewmodels/payment_list_viewmodel.dart';

class PaymentReceiptPage extends StatefulWidget {
  final int paymentId;

  const PaymentReceiptPage({super.key, required this.paymentId});

  @override
  State<PaymentReceiptPage> createState() => _PaymentReceiptPageState();
}

class _PaymentReceiptPageState extends State<PaymentReceiptPage> {
  final PaymentListViewModel _viewModel = AppInjection.createPaymentViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);
    _viewModel.loadReceipt(widget.paymentId);
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

  Future<void> _reload() {
    return _viewModel.loadReceipt(widget.paymentId);
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _viewModel.receipt;

    return Scaffold(
      appBar: AppBar(
        title: Text(receipt?.invoiceNumber ?? 'Receipt'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _viewModel.isLoadingReceipt ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final receipt = _viewModel.receipt;

    if (_viewModel.isLoadingReceipt && receipt == null) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading receipt...',
        skeletonItemCount: 7,
      );
    }

    if (_viewModel.receiptError != null && receipt == null) {
      return AppErrorWidget(
        title: 'Receipt could not be loaded',
        error: _viewModel.receiptError,
        onRetry: _reload,
      );
    }

    if (receipt == null) {
      return const AppEmptyStateWidget(
        title: 'Receipt unavailable',
        message: 'The requested payment receipt is not available.',
        icon: Icons.receipt_long_outlined,
      );
    }

    final dateFormatter = DateFormat('dd.MM.yyyy. HH:mm');

    return RefreshIndicator(
      onRefresh: _reload,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                if (_viewModel.receiptError != null)
                  AppInlineError(
                    title: 'Receipt could not be refreshed',
                    error: _viewModel.receiptError,
                    onRetry: _reload,
                    margin: const EdgeInsets.only(bottom: 16),
                  ),
                Card(
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
                        const Text(
                          'Payment receipt',
                          textAlign: TextAlign.center,
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
                        _ReceiptRow(
                          label: 'Appointment ID',
                          value: receipt.appointmentId.toString(),
                        ),
                        _ReceiptRow(label: 'Purpose', value: receipt.purpose),
                        const Divider(height: 32),
                        _ReceiptRow(label: 'Client', value: receipt.clientName),
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
                        if (receipt.hasRefundInformation) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Refund information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (receipt.refundReason != null)
                            _ReceiptRow(
                              label: 'Refund reason',
                              value: receipt.refundReason!,
                            ),
                          if (receipt.refundRequestedAtUtc != null)
                            _ReceiptRow(
                              label: 'Refund requested at',
                              value: dateFormatter.format(
                                receipt.refundRequestedAtUtc!.toLocal(),
                              ),
                            ),
                          if (receipt.refundedAtUtc != null)
                            _ReceiptRow(
                              label: 'Refunded at',
                              value: dateFormatter.format(
                                receipt.refundedAtUtc!.toLocal(),
                              ),
                            ),
                          if (receipt.stripeRefundId != null)
                            _ReceiptRow(
                              label: 'Stripe refund ID',
                              value: receipt.stripeRefundId!,
                            ),
                          if (receipt.refundFailureReason != null)
                            _ReceiptRow(
                              label: 'Refund error',
                              value: receipt.refundFailureReason!,
                            ),
                        ],
                        const SizedBox(height: 24),
                        const Text(
                          'This receipt was generated by '
                          'the MindBloom administration system.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                        if (_viewModel.isLoadingReceipt) ...[
                          const SizedBox(height: 20),
                          const AppInlineLoadingIndicator(
                            message: 'Refreshing receipt...',
                          ),
                        ],
                      ],
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
