import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../viewmodels/membership_viewmodel.dart';

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
    _viewModel.addListener(_refresh);
    _viewModel.loadMyMemberships();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('My memberships')),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _viewModel.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _viewModel.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          : _viewModel.memberships.isEmpty
          ? const Center(child: Text('You do not have memberships yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _viewModel.memberships.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final membership = _viewModel.memberships[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          membership.therapistName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(membership.planType),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: membership.totalSessions == 0
                              ? 0
                              : membership.remainingSessions /
                                    membership.totalSessions,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${membership.remainingSessions} of ${membership.totalSessions} sessions remaining',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Price: ${membership.price.toStringAsFixed(2)} KM',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          membership.expiresAtUtc == null
                              ? 'No expiration date'
                              : 'Expires: ${formatter.format(membership.expiresAtUtc!.toLocal())}',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          membership.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: membership.isActive
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
