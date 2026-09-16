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

const _paymentBackground = Color(0xFFFCFAFF);
const _paymentSurface = Color(0xFFFFFFFF);
const _paymentLavender = Color(0xFFF6F0FC);
const _paymentBorder = Color(0xFFE7DDF1);
const _paymentPrimary = Color(0xFF6D4F91);
const _paymentText = Color(0xFF372D45);
const _paymentMuted = Color(0xFF6C6278);
const _paymentRadius = 20.0;

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
      backgroundColor: _paymentBackground,
      appBar: AppBar(
        title: const Text('Payment history'),
        backgroundColor: _paymentBackground,
        surfaceTintColor: Colors.transparent,
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PaymentHistoryCard(
                payment: payment,
                icon: _statusIcon(payment.status),
                createdDate: formatter.format(payment.createdAtUtc.toLocal()),
                receiptAvailable: receiptAvailable,
                onTap: receiptAvailable
                    ? () => _openTransaction(payment)
                    : null,
              ),
            );
          }),
          if (_viewModel.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_viewModel.loadMoreError != null)
            AppInlineError(
              title: 'More payments could not be loaded',
              error: _viewModel.loadMoreError,
              onRetry: _viewModel.loadMorePayments,
              margin: const EdgeInsets.only(top: 6),
            )
          else if (_viewModel.hasMorePages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: OutlinedButton.icon(
                onPressed: _viewModel.loadMorePayments,
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  final PaymentModel payment;
  final IconData icon;
  final String createdDate;
  final bool receiptAvailable;
  final VoidCallback? onTap;

  const _PaymentHistoryCard({
    required this.payment,
    required this.icon,
    required this.createdDate,
    required this.receiptAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reference =
        payment.isAppointmentPayment && payment.appointmentId != null
        ? 'Appointment #${payment.appointmentId}'
        : payment.isMembershipPayment && payment.membershipId != null
        ? 'Membership #${payment.membershipId}'
        : null;

    return Material(
      color: _paymentSurface,
      borderRadius: BorderRadius.circular(_paymentRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_paymentRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_paymentRadius),
            border: Border.all(color: _paymentBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: _paymentLavender,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: _paymentPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.therapistName.trim().isEmpty
                              ? payment.displayType
                              : payment.therapistName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _paymentText,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.displayType,
                          style: const TextStyle(
                            color: _paymentMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _PaymentStatusChip(label: payment.displayStatus),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                payment.purpose,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _paymentText, height: 1.35),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PaymentMetaPill(
                    icon: Icons.calendar_today_outlined,
                    label: createdDate,
                  ),
                  if (reference != null)
                    _PaymentMetaPill(
                      icon: Icons.tag_outlined,
                      label: reference,
                    ),
                  if (payment.isRefundPending)
                    const _PaymentMetaPill(
                      icon: Icons.hourglass_top,
                      label: 'Refund processing',
                    ),
                  if (payment.isRefunded && payment.refundedAtUtc != null)
                    const _PaymentMetaPill(
                      icon: Icons.replay_circle_filled,
                      label: 'Amount returned',
                    ),
                  if (payment.isRefundFailed)
                    const _PaymentMetaPill(
                      icon: Icons.error_outline,
                      label: 'Refund failed',
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${payment.amount.toStringAsFixed(2)} ${payment.currency}',
                      style: const TextStyle(
                        color: _paymentText,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (receiptAvailable) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.chevron_right, color: _paymentPrimary),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentStatusChip extends StatelessWidget {
  final String label;

  const _PaymentStatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _paymentLavender,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _paymentBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _paymentPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PaymentMetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _paymentLavender,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _paymentPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _paymentText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
