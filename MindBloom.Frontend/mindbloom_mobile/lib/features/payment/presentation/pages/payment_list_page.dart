import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_mobile/features/payment/data/models/payment_model.dart';
import '../../../membership/presentation/pages/membership_receipt_page.dart';
import '../../../../app/di/injection.dart';
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

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    await _viewModel.loadPayments();
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
      appBar: AppBar(title: const Text('Payment history')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.payments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.payments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _viewModel.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _refresh,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_viewModel.payments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: Text('You do not have any payments yet.')),
          ],
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy.');

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _viewModel.payments.length,
        itemBuilder: (context, index) {
          final payment = _viewModel.payments[index];

          final receiptAvailable = payment.isPaid || payment.hasRefundProcess;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: receiptAvailable
                  ? () {
                      _openTransaction(payment);
                    }
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
                    const Text('Refund failed', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
