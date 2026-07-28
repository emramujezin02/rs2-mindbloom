import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/membership_model.dart';
import '../viewmodels/membership_viewmodel.dart';
import 'membership_receipt_page.dart';

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
      appBar: AppBar(
        title: const Text('My memberships'),
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
        padding: const EdgeInsets.all(16),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onReceipt,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(highlightActive ? Icons.verified : Icons.history),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      membership.displayPlanName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(label: Text(membership.displayMembershipStatus)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                membership.therapistName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (membership.isPaid) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(
                  '${membership.remainingSessions} of '
                  '${membership.totalSessions} sessions remaining',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text('${membership.usedSessions} sessions used'),
              ],
              const SizedBox(height: 12),
              Text(
                'Price: '
                '${membership.price.toStringAsFixed(2)} KM',
              ),
              const SizedBox(height: 6),
              Text(
                'Payment: '
                '${membership.displayPaymentStatus}',
              ),
              if (membership.purchasedAtUtc != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Start date: '
                  '${formatter.format(membership.purchasedAtUtc!.toLocal())}',
                ),
              ],
              if (membership.expiresAtUtc != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Expiration date: '
                  '${formatter.format(membership.expiresAtUtc!.toLocal())}',
                ),
              ],
              if (onReceipt != null) ...[
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, size: 18),
                      SizedBox(width: 6),
                      Text('View receipt'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
    );
  }
}
