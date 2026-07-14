import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
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

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    await _viewModel.loadMyMemberships();
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

    if (_viewModel.memberships.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: Text('You do not have memberships yet.')),
          ],
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy.');

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),

        itemCount: _viewModel.memberships.length,

        separatorBuilder: (context, index) => const SizedBox(height: 12),

        itemBuilder: (context, index) {
          final membership = _viewModel.memberships[index];

          return Card(
            child: InkWell(
              onTap: membership.isPaid
                  ? () {
                      _openReceipt(membership.id);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            membership.therapistName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(
                          membership.isPaid
                              ? Icons.check_circle
                              : Icons.hourglass_top,
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(membership.planType),

                    const SizedBox(height: 8),

                    if (membership.isPaid)
                      LinearProgressIndicator(
                        value: membership.totalSessions == 0
                            ? 0
                            : membership.remainingSessions /
                                  membership.totalSessions,
                      ),

                    if (membership.isPaid) const SizedBox(height: 8),

                    if (membership.isPaid)
                      Text(
                        '${membership.remainingSessions} of '
                        '${membership.totalSessions} sessions remaining',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                    const SizedBox(height: 8),

                    Text(
                      'Price: '
                      '${membership.price.toStringAsFixed(2)} KM',
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Payment: '
                      '${membership.displayPaymentStatus}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    if (membership.purchasedAtUtc != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Purchased: '
                        '${formatter.format(membership.purchasedAtUtc!.toLocal())}',
                      ),
                    ],

                    if (membership.expiresAtUtc != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Expires: '
                        '${formatter.format(membership.expiresAtUtc!.toLocal())}',
                      ),
                    ],

                    const SizedBox(height: 8),

                    Text(
                      membership.isActive
                          ? 'Active'
                          : membership.isPaid
                          ? 'Inactive'
                          : 'Awaiting payment',
                      style: TextStyle(
                        color: membership.isActive
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (membership.isPaid) ...[
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.receipt_long, size: 18),
                          SizedBox(width: 6),
                          Text('Tap to view receipt'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
