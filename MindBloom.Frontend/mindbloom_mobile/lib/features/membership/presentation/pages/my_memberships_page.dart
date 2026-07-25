import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
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
      appBar: AppBar(title: const Text('My memberships')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.memberships.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.memberships.isEmpty) {
      return _ErrorState(message: _viewModel.error!, onRetry: _refresh);
    }

    if (_viewModel.memberships.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Icon(Icons.card_membership_outlined, size: 64),
            SizedBox(height: 16),
            Text(
              'You do not have memberships yet.',
              textAlign: TextAlign.center,
            ),
          ],
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
          const _SectionTitle('Active membership'),

          const SizedBox(height: 10),

          if (active.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'You currently do not have an active membership.',
                  textAlign: TextAlign.center,
                ),
              ),
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
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'There are no previous memberships.',
                  textAlign: TextAlign.center,
                ),
              ),
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

          if (_viewModel.error != null) ...[
            const SizedBox(height: 12),
            Text(
              _viewModel.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
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

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 58),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
