import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/membership_model.dart';
import '../viewmodels/membership_viewmodel.dart';
import 'membership_receipt_page.dart';

const _membershipBackground = Color(0xFFFCFAFF);
const _membershipSurface = Color(0xFFFFFFFF);
const _membershipLavender = Color(0xFFF6F0FC);
const _membershipBorder = Color(0xFFE7DDF1);
const _membershipPrimary = Color(0xFF6D4F91);
const _membershipText = Color(0xFF372D45);
const _membershipMuted = Color(0xFF6C6278);
const _membershipRadius = 20.0;

class MyMembershipsPage extends StatefulWidget {
  const MyMembershipsPage({super.key});

  @override
  State<MyMembershipsPage> createState() => _MyMembershipsPageState();
}

class _MyMembershipsPageState extends State<MyMembershipsPage> {
  final MembershipViewModel _viewModel =
      AppInjection.createMembershipViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
    _viewModel.loadMyMemberships();
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
    return _viewModel.loadMyMemberships();
  }

  void _openReceipt(int membershipId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MembershipReceiptPage(membershipId: membershipId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _membershipBackground,
      appBar: AppBar(
        title: const Text('My memberships'),
        backgroundColor: _membershipBackground,
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
    if (_viewModel.isLoading && _viewModel.memberships.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading memberships...',
        skeletonItemCount: 4,
      );
    }

    if (_viewModel.error != null && _viewModel.memberships.isEmpty) {
      return AppErrorWidget(
        title: 'Memberships could not be loaded',
        error: _viewModel.error,
        onRetry: _refresh,
      );
    }

    if (_viewModel.memberships.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: const AppEmptyStateWidget(
          title: 'No memberships',
          message: 'You have not purchased a membership yet.',
          icon: Icons.card_membership_outlined,
        ),
      );
    }

    final active = _viewModel.activeMemberships;
    final history = _viewModel.membershipHistory;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Memberships could not be refreshed',
              error: _viewModel.error,
              onRetry: _refresh,
              margin: const EdgeInsets.only(bottom: 16),
            ),
          const _SectionTitle('Active membership'),
          const SizedBox(height: 10),
          if (active.isEmpty)
            const _MembershipSectionEmptyState(
              icon: Icons.card_membership_outlined,
              message: 'You currently do not have an active membership.',
            )
          else
            ...active.map(
              (membership) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MembershipCard(
                  membership: membership,
                  onReceipt: membership.isPaid
                      ? () => _openReceipt(membership.id)
                      : null,
                  highlightActive: true,
                ),
              ),
            ),
          const SizedBox(height: 24),
          const _SectionTitle('Membership history'),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const _MembershipSectionEmptyState(
              icon: Icons.history_outlined,
              message: 'There are no previous memberships.',
            )
          else
            ...history.map(
              (membership) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MembershipCard(
                  membership: membership,
                  onReceipt: membership.isPaid
                      ? () => _openReceipt(membership.id)
                      : null,
                  highlightActive: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MembershipSectionEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MembershipSectionEmptyState({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _membershipSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_membershipRadius),
        side: const BorderSide(color: _membershipBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(icon, size: 42, color: _membershipPrimary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _membershipMuted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  final MembershipModel membership;
  final VoidCallback? onReceipt;
  final bool highlightActive;

  const _MembershipCard({
    required this.membership,
    required this.onReceipt,
    required this.highlightActive,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy.');

    final progress = membership.totalSessions <= 0
        ? 0.0
        : (membership.remainingSessions / membership.totalSessions).clamp(
            0.0,
            1.0,
          );

    return Material(
      color: _membershipSurface,
      borderRadius: BorderRadius.circular(_membershipRadius),
      child: InkWell(
        onTap: onReceipt,
        borderRadius: BorderRadius.circular(_membershipRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: _membershipLavender,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      highlightActive ? Icons.verified : Icons.history,
                      color: _membershipPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      membership.displayPlanName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _membershipText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MembershipStatusChip(
                    label: membership.displayMembershipStatus,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                membership.therapistName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _membershipMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (membership.isPaid) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    color: _membershipPrimary,
                    backgroundColor: _membershipLavender,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${membership.remainingSessions} of '
                  '${membership.totalSessions} sessions remaining',
                  style: const TextStyle(
                    color: _membershipText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${membership.usedSessions} sessions used',
                  style: const TextStyle(color: _membershipMuted),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MembershipMetaPill(
                    icon: Icons.payments_outlined,
                    label: '${membership.price.toStringAsFixed(2)} KM',
                  ),
                  _MembershipMetaPill(
                    icon: Icons.receipt_long_outlined,
                    label: membership.displayPaymentStatus,
                  ),
                ],
              ),
              if (membership.purchasedAtUtc != null) ...[
                const SizedBox(height: 8),
                _MembershipInfoRow(
                  label: 'Start date',
                  value: formatter.format(membership.purchasedAtUtc!.toLocal()),
                ),
              ],
              if (membership.expiresAtUtc != null) ...[
                const SizedBox(height: 8),
                _MembershipInfoRow(
                  label: 'Expiration date',
                  value: formatter.format(membership.expiresAtUtc!.toLocal()),
                ),
              ],
              if (onReceipt != null) ...[
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 18,
                      color: _membershipPrimary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'View receipt',
                      style: TextStyle(
                        color: _membershipPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ).withMembershipBorder();
  }
}

extension _MembershipBorder on Widget {
  Widget withMembershipBorder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_membershipRadius),
        border: Border.all(color: _membershipBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: this,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String value;

  const _SectionTitle(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        color: _membershipText,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MembershipStatusChip extends StatelessWidget {
  final String label;

  const _MembershipStatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _membershipLavender,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _membershipBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _membershipPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MembershipMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MembershipMetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _membershipLavender,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _membershipPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _membershipText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _MembershipInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _membershipMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _membershipText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
