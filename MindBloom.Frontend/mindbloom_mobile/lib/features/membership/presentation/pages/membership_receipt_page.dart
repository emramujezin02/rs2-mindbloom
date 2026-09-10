import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_message.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/membership_receipt_model.dart';
import '../viewmodels/membership_viewmodel.dart';

const _membershipReceiptBackground = Color(0xFFFCFAFF);
const _membershipReceiptSurface = Color(0xFFFFFFFF);
const _membershipReceiptLavender = Color(0xFFF6F0FC);
const _membershipReceiptBorder = Color(0xFFE7DDF1);
const _membershipReceiptPrimary = Color(0xFF6D4F91);
const _membershipReceiptText = Color(0xFF372D45);
const _membershipReceiptMuted = Color(0xFF6C6278);
const _membershipReceiptRadius = 20.0;

class MembershipReceiptPage extends StatefulWidget {
  final int membershipId;

  const MembershipReceiptPage({super.key, required this.membershipId});

  @override
  State<MembershipReceiptPage> createState() => _MembershipReceiptPageState();
}

class _MembershipReceiptPageState extends State<MembershipReceiptPage> {
  final MembershipViewModel _viewModel =
      AppInjection.createMembershipViewModel();

  MembershipReceiptModel? _receipt;
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _loadReceipt() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final receipt = await _viewModel.getReceipt(widget.membershipId);

      if (!mounted) {
        return;
      }

      setState(() {
        _receipt = receipt;
        _error = null;
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = AppErrorMessage.from(exception);
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
      backgroundColor: _membershipReceiptBackground,
      appBar: AppBar(
        title: const Text('Membership receipt'),
        backgroundColor: _membershipReceiptBackground,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadReceipt,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _receipt == null) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading membership receipt...',
        skeletonItemCount: 5,
      );
    }

    if (_error != null && _receipt == null) {
      return AppErrorWidget(
        title: 'Receipt could not be loaded',
        error: _error,
        onRetry: _loadReceipt,
      );
    }

    final receipt = _receipt;

    if (receipt == null) {
      return const AppEmptyStateWidget(
        title: 'Receipt unavailable',
        message: 'The requested membership receipt is not available.',
        icon: Icons.receipt_long_outlined,
      );
    }

    final dateFormatter = DateFormat('dd.MM.yyyy. HH:mm');

    return RefreshIndicator(
      onRefresh: _loadReceipt,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          if (_error != null)
            AppInlineError(
              title: 'Receipt could not be refreshed',
              error: _error,
              onRetry: _loadReceipt,
              margin: const EdgeInsets.only(bottom: 16),
            ),
          _MembershipReceiptCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _MembershipReceiptHeader(),
                const SizedBox(height: 12),
                Text(
                  receipt.invoiceNumber,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _membershipReceiptText,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 24),
                _ReceiptRow(label: 'Client', value: receipt.clientName),
                const _ReceiptDivider(),
                _ReceiptRow(label: 'Therapist', value: receipt.therapistName),
                const _ReceiptDivider(),
                _ReceiptRow(label: 'Package', value: receipt.planType),
                const _ReceiptDivider(),
                _ReceiptRow(
                  label: 'Sessions',
                  value: receipt.totalSessions.toString(),
                ),
                const _ReceiptDivider(),
                _ReceiptRow(
                  label: 'Amount',
                  value:
                      '${receipt.amount.toStringAsFixed(2)} '
                      '${receipt.currency}',
                  emphasize: true,
                ),
                const _ReceiptDivider(),
                _ReceiptRow(label: 'Status', value: receipt.paymentStatus),
                const _ReceiptDivider(),
                _ReceiptRow(
                  label: 'Paid at',
                  value: dateFormatter.format(receipt.paidAtUtc.toLocal()),
                ),
                if (receipt.expiresAtUtc != null) ...[
                  const _ReceiptDivider(),
                  _ReceiptRow(
                    label: 'Expires',
                    value: dateFormatter.format(
                      receipt.expiresAtUtc!.toLocal(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 340;
        final labelWidget = Text(
          label,
          style: const TextStyle(
            color: _membershipReceiptMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        );
        final valueWidget = Text(
          value,
          textAlign: narrow ? TextAlign.left : TextAlign.right,
          style: TextStyle(
            color: _membershipReceiptText,
            fontSize: emphasize ? 18 : null,
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
            height: 1.3,
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
            Expanded(child: labelWidget),
            const SizedBox(width: 12),
            Flexible(child: valueWidget),
          ],
        );
      },
    );
  }
}

class _MembershipReceiptHeader extends StatelessWidget {
  const _MembershipReceiptHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: const BoxDecoration(
            color: _membershipReceiptLavender,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.receipt_long,
            size: 38,
            color: _membershipReceiptPrimary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Membership receipt',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _membershipReceiptMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MembershipReceiptCard extends StatelessWidget {
  final Widget child;

  const _MembershipReceiptCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _membershipReceiptSurface,
        borderRadius: BorderRadius.circular(_membershipReceiptRadius),
        border: Border.all(color: _membershipReceiptBorder),
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

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 26, color: _membershipReceiptBorder);
  }
}
