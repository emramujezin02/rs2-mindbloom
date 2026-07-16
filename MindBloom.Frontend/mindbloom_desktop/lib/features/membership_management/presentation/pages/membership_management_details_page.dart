import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../data/models/admin_membership_details_model.dart';
import '../viewmodels/membership_management_details_viewmodel.dart';

class MembershipManagementDetailsPage extends StatefulWidget {
  final int membershipId;

  const MembershipManagementDetailsPage({
    super.key,
    required this.membershipId,
  });

  @override
  State<MembershipManagementDetailsPage> createState() =>
      _MembershipManagementDetailsPageState();
}

class _MembershipManagementDetailsPageState
    extends State<MembershipManagementDetailsPage> {
  late final MembershipManagementDetailsViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createMembershipManagementDetailsViewModel();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.loadMembership(widget.membershipId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Membership #${widget.membershipId}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _viewModel.isLoading
                ? null
                : () {
                    _viewModel.loadMembership(widget.membershipId);
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.membership == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.membership == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 58),
              const SizedBox(height: 12),
              Text(_viewModel.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  _viewModel.loadMembership(widget.membershipId);
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final membership = _viewModel.membership;

    if (membership == null) {
      return const Center(child: Text('Membership not found.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummary(membership),

              const SizedBox(height: 20),

              _buildPeople(membership),

              const SizedBox(height: 20),

              _buildPayment(membership),

              const SizedBox(height: 20),

              _buildUsageHistory(membership),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(AdminMembershipDetailsModel membership) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    final progress = membership.totalSessions <= 0
        ? 0.0
        : membership.remainingSessions / membership.totalSessions;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Text(
                  'Membership #${membership.id}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.card_membership, size: 18),
                  label: Text(membership.membershipStatus),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetailsGrid(
              children: [
                _DetailsItem(
                  label: 'Plan',
                  value: _formatPlan(membership.planType),
                ),
                _DetailsItem(
                  label: 'Price',
                  value: '${membership.price.toStringAsFixed(2)} USD',
                ),
                _DetailsItem(
                  label: 'Purchased',
                  value: membership.purchasedAtUtc == null
                      ? 'Not purchased'
                      : formatter.format(membership.purchasedAtUtc!.toLocal()),
                ),
                _DetailsItem(
                  label: 'Expires',
                  value: membership.expiresAtUtc == null
                      ? 'No expiration date'
                      : formatter.format(membership.expiresAtUtc!.toLocal()),
                ),
                _DetailsItem(
                  label: 'Created',
                  value: formatter.format(membership.createdAtUtc.toLocal()),
                ),
                _DetailsItem(
                  label: 'Last updated',
                  value: membership.updatedAtUtc == null
                      ? '—'
                      : formatter.format(membership.updatedAtUtc!.toLocal()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '${membership.remainingSessions} of '
              '${membership.totalSessions} sessions remaining',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricChip(
                  label: 'Remaining',
                  value: membership.remainingSessions,
                  icon: Icons.event_available,
                ),
                _MetricChip(
                  label: 'Reserved',
                  value: membership.reservedSessions,
                  icon: Icons.schedule,
                ),
                _MetricChip(
                  label: 'Consumed',
                  value: membership.consumedSessions,
                  icon: Icons.check_circle,
                ),
                _MetricChip(
                  label: 'Restored',
                  value: membership.restoredSessions,
                  icon: Icons.replay,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeople(AdminMembershipDetailsModel membership) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _PersonCard(
            title: 'Client',
            id: membership.clientId,
            userId: membership.clientUserId,
            name: membership.clientName,
            email: membership.clientEmail,
            icon: Icons.person_outline,
          ),
          _PersonCard(
            title: 'Therapist',
            id: membership.therapistId,
            userId: membership.therapistUserId,
            name: membership.therapistName,
            email: membership.therapistEmail,
            icon: Icons.psychology_outlined,
          ),
        ];

        if (constraints.maxWidth < 750) {
          return Column(
            children: [cards[0], const SizedBox(height: 12), cards[1]],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }

  Widget _buildPayment(AdminMembershipDetailsModel membership) {
    final payment = membership.payment;

    if (payment == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.payment_outlined),
          title: Text('Payment not created'),
          subtitle: Text(
            'No membership payment record is connected to this membership.',
          ),
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _DetailsGrid(
              children: [
                _DetailsItem(label: 'Payment ID', value: '#${payment.id}'),
                _DetailsItem(label: 'Status', value: payment.status),
                _DetailsItem(
                  label: 'Amount',
                  value:
                      '${payment.amount.toStringAsFixed(2)} '
                      '${payment.currency.toUpperCase()}',
                ),
                _DetailsItem(
                  label: 'Paid at',
                  value: payment.paidAtUtc == null
                      ? 'Not paid'
                      : formatter.format(payment.paidAtUtc!.toLocal()),
                ),
                _DetailsItem(
                  label: 'Created',
                  value: formatter.format(payment.createdAtUtc.toLocal()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Stripe PaymentIntent',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            SelectableText(payment.stripePaymentIntentId),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageHistory(AdminMembershipDetailsModel membership) {
    if (membership.usages.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Center(
            child: Text('This membership does not have any usage records.'),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage history (${membership.usages.length})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Usage ID')),
                        DataColumn(label: Text('Appointment')),
                        DataColumn(label: Text('Appointment date')),
                        DataColumn(label: Text('Appointment status')),
                        DataColumn(label: Text('Usage status')),
                        DataColumn(label: Text('Reserved')),
                        DataColumn(label: Text('Consumed')),
                        DataColumn(label: Text('Restored')),
                        DataColumn(label: Text('Reason')),
                      ],
                      rows: membership.usages.map(_buildUsageRow).toList(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildUsageRow(AdminMembershipUsageModel usage) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    String formatNullable(DateTime? value) {
      return value == null ? '—' : formatter.format(value.toLocal());
    }

    return DataRow(
      cells: [
        DataCell(Text('#${usage.id}')),
        DataCell(Text('#${usage.appointmentId}')),
        DataCell(Text(formatter.format(usage.appointmentStartUtc.toLocal()))),
        DataCell(Text(usage.appointmentStatus)),
        DataCell(Chip(label: Text(usage.status))),
        DataCell(Text(formatNullable(usage.reservedAtUtc))),
        DataCell(Text(formatNullable(usage.consumedAtUtc))),
        DataCell(Text(formatNullable(usage.restoredAtUtc))),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              usage.resolutionReason ?? '—',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  String _formatPlan(String planType) {
    switch (planType) {
      case 'TenSessions':
        return '10 sessions package';

      case 'TwentySessions':
        return '20 sessions package';

      case 'ThirtySessions':
        return '30 sessions package';

      default:
        return planType;
    }
  }
}

class _DetailsGrid extends StatelessWidget {
  final List<Widget> children;

  const _DetailsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = width >= 900
            ? 3
            : width >= 600
            ? 2
            : 1;

        final itemWidth = (width - ((columns - 1) * 12)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _DetailsItem extends StatelessWidget {
  final String label;

  final String value;

  const _DetailsItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 5),
            SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;

  final int value;

  final IconData icon;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text('$label: $value'));
  }
}

class _PersonCard extends StatelessWidget {
  final String title;

  final int id;

  final int userId;

  final String name;

  final String email;

  final IconData icon;

  const _PersonCard({
    required this.title,
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailsItem(label: 'Name', value: name),
            const SizedBox(height: 10),
            _DetailsItem(label: 'Email', value: email),
            const SizedBox(height: 10),
            _DetailsItem(label: '$title ID', value: id.toString()),
            const SizedBox(height: 10),
            _DetailsItem(label: 'User ID', value: userId.toString()),
          ],
        ),
      ),
    );
  }
}
