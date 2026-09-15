import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../viewmodels/payment_list_viewmodel.dart';

const _receiptBackground = Color(0xFFFCFAFF);
const _receiptSurface = Color(0xFFFFFFFF);
const _receiptLavender = Color(0xFFF6F0FC);
const _receiptBorder = Color(0xFFE7DDF1);
const _receiptPrimary = Color(0xFF6D4F91);
const _receiptText = Color(0xFF372D45);
const _receiptMuted = Color(0xFF6C6278);
const _receiptRadius = 20.0;

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
      backgroundColor: _receiptBackground,
      appBar: AppBar(
        title: Text(receipt?.invoiceNumber ?? 'Receipt'),
        backgroundColor: _receiptBackground,
        surfaceTintColor: Colors.transparent,
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
                _ReceiptCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ReceiptHeader(title: 'Payment receipt'),
                      const SizedBox(height: 24),
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
                      const _ReceiptDivider(),
                      _ReceiptRow(label: 'Client', value: receipt.clientName),
                      _ReceiptRow(
                        label: 'Therapist',
                        value: receipt.therapistName,
                      ),
                      const _ReceiptDivider(),
                      _ReceiptRow(label: 'Status', value: receipt.status),
                      _ReceiptRow(
                        label: 'Amount',
                        value:
                            '${receipt.amount.toStringAsFixed(2)} '
                            '${receipt.currency}',
                        emphasize: true,
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
                      const _ReceiptDivider(),
                      _ReceiptRow(
                        label: 'Stripe PaymentIntent',
                        value: receipt.stripePaymentIntentId,
                      ),
                      if (receipt.hasRefundInformation) ...[
                        const SizedBox(height: 20),
                        const _ReceiptSectionTitle('Refund information'),
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
                        'This receipt was generated by the MindBloom administration system.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _receiptMuted, fontSize: 12),
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
  final bool emphasize;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 420;

          final labelWidget = Text(
            label,
            style: const TextStyle(
              color: _receiptMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          );

          final valueWidget = SelectableText(
            value,
            textAlign: narrow ? TextAlign.left : TextAlign.right,
            style: TextStyle(
              color: _receiptText,
              fontSize: emphasize ? 17 : null,
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              height: 1.25,
            ),
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), valueWidget],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 170, child: labelWidget),
              const SizedBox(width: 12),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _ReceiptHeader extends StatelessWidget {
  final String title;

  const _ReceiptHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: const BoxDecoration(
            color: _receiptLavender,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.spa, size: 36, color: _receiptPrimary),
        ),
        const SizedBox(height: 12),
        const Text(
          'MindBloom',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _receiptText,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _receiptMuted),
        ),
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Widget child;

  const _ReceiptCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _receiptSurface,
        borderRadius: BorderRadius.circular(_receiptRadius),
        border: Border.all(color: _receiptBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ReceiptSectionTitle extends StatelessWidget {
  final String title;

  const _ReceiptSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: _receiptText,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 30, color: _receiptBorder);
  }
}
