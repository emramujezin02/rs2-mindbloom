import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../membership/presentation/pages/membership_receipt_page.dart';
import '../../data/models/payment_model.dart';
import '../viewmodels/payment_list_viewmodel.dart';
import 'payment_receipt_page.dart';

class PaymentListPage extends StatefulWidget {
  const PaymentListPage({super.key});

  @override
  State<PaymentListPage> createState() => _PaymentListPageState();
}

class _PaymentListPageState extends State<PaymentListPage> {
  final PaymentListViewModel _viewModel = AppInjection.createPaymentViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
    _viewModel.loadPayments();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() {
    return _viewModel.loadPayments();
  }

  void _openTransaction(PaymentModel payment) {
    if (payment.isAppointmentPayment) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentReceiptPage(paymentId: payment.id),
        ),
      );
      return;
    }

    final membershipId = payment.membershipId;

    if (payment.isMembershipPayment && membershipId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MembershipReceiptPage(membershipId: membershipId),
        ),
      );
    }
  }

  IconData _statusIcon(String status) {
    final normalized = status.trim().toLowerCase();

    if (normalized == 'paid') {
      return Icons.check_circle;
    }

    if (normalized == 'refundpending') {
      return Icons.hourglass_top;
    }

    if (normalized == 'refunded') {
      return Icons.replay_circle_filled;
    }

    if (normalized == 'refundfailed') {
      return Icons.error_outline;
    }

    if (normalized == 'failed') {
      return Icons.cancel;
    }

    return Icons.payments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment history'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _viewModel.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.payments.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading payment history...',
        skeletonItemCount: 5,
      );
    }

    if (_viewModel.error != null && _viewModel.payments.isEmpty) {
      return AppErrorWidget(
        title: 'Payment history could not be loaded',
        error: _viewModel.error,
        onRetry: _refresh,
      );
    }

    if (_viewModel.payments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: const AppEmptyStateWidget(
          title: 'No payments',
          message: 'You do not have any payment transactions yet.',
          icon: Icons.payments_outlined,
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy.');

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Payment history could not be refreshed',
              error: _viewModel.error,
              onRetry: _refresh,
              margin: const EdgeInsets.only(bottom: 12),
            ),
          ..._viewModel.payments.map((payment) {
            final receiptAvailable = payment.isPaid || payment.hasRefundProcess;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: receiptAvailable
                    ? () => _openTransaction(payment)
                    : null,
                leading: Icon(_statusIcon(payment.status)),
                title: Text(payment.therapistName),
                subtitle: Text(
                  '${payment.displayType}\n'
                  '${payment.purpose}\n'
                  '${formatter.format(payment.createdAtUtc.toLocal())}'
                  '${payment.isAppointmentPayment && payment.appointmentId != null ? '\nAppointment #${payment.appointmentId}' : ''}'
                  '${payment.isMembershipPayment && payment.membershipId != null ? '\nMembership #${payment.membershipId}' : ''}'
                  '${receiptAvailable ? '\nTap to view transaction details' : ''}',
                ),
                isThreeLine: false,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${payment.amount.toStringAsFixed(2)} '
                      '${payment.currency}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(payment.displayStatus),
                    if (receiptAvailable)
                      const Icon(Icons.chevron_right, size: 18),
                    if (payment.isRefundPending)
                      const Text(
                        'Refund processing',
                        style: TextStyle(fontSize: 11),
                      ),
                    if (payment.isRefunded && payment.refundedAtUtc != null)
                      const Text(
                        'Amount returned',
                        style: TextStyle(fontSize: 11),
                      ),
                    if (payment.isRefundFailed)
                      const Text(
                        'Refund failed',
                        style: TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
