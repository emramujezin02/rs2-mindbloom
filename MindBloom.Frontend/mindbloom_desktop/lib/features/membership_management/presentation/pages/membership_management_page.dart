import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/admin_membership_model.dart';
import '../viewmodels/membership_management_viewmodel.dart';

class MembershipManagementPage extends StatefulWidget {
  const MembershipManagementPage({super.key});

  @override
  State<MembershipManagementPage> createState() =>
      _MembershipManagementPageState();
}

class _MembershipManagementPageState extends State<MembershipManagementPage> {
  late final MembershipManagementViewModel _viewModel;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createMembershipManagementViewModel();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.loadMemberships();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _searchController.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _search() async {
    await _viewModel.applySearch(_searchController.text);
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    await _viewModel.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),

          const SizedBox(height: 20),

          _buildFilters(),

          const SizedBox(height: 16),

          Expanded(child: _buildContent()),

          const SizedBox(height: 12),

          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Membership management',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('Review memberships, payments and session usage.'),
          ],
        ),
        Chip(
          avatar: const Icon(Icons.card_membership, size: 18),
          label: Text('${_viewModel.totalCount} memberships'),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  hintText: 'ID, client or therapist',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  _search();
                },
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<int?>(
                initialValue: _viewModel.planType,
                decoration: const InputDecoration(
                  labelText: 'Plan',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<int?>(value: null, child: Text('All plans')),
                  DropdownMenuItem<int?>(value: 1, child: Text('10 sessions')),
                  DropdownMenuItem<int?>(value: 2, child: Text('20 sessions')),
                  DropdownMenuItem<int?>(value: 3, child: Text('30 sessions')),
                ],
                onChanged: (value) {
                  _viewModel.setPlanType(value);
                },
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String?>(
                initialValue: _viewModel.membershipStatus,
                decoration: const InputDecoration(
                  labelText: 'Membership status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Active',
                    child: Text('Active'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Inactive',
                    child: Text('Inactive'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'PendingPayment',
                    child: Text('Pending payment'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Expired',
                    child: Text('Expired'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Depleted',
                    child: Text('Depleted'),
                  ),
                ],
                onChanged: (value) {
                  _viewModel.setMembershipStatus(value);
                },
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<int?>(
                initialValue: _viewModel.paymentStatus,
                decoration: const InputDecoration(
                  labelText: 'Payment status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All payments'),
                  ),
                  DropdownMenuItem<int?>(value: 1, child: Text('Pending')),
                  DropdownMenuItem<int?>(value: 2, child: Text('Paid')),
                  DropdownMenuItem<int?>(value: 3, child: Text('Failed')),
                  DropdownMenuItem<int?>(value: 4, child: Text('Refunded')),
                  DropdownMenuItem<int?>(
                    value: 5,
                    child: Text('Refund pending'),
                  ),
                  DropdownMenuItem<int?>(
                    value: 6,
                    child: Text('Refund failed'),
                  ),
                ],
                onChanged: (value) {
                  _viewModel.setPaymentStatus(value);
                },
              ),
            ),
            FilledButton.icon(
              onPressed: _viewModel.isLoading ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
            OutlinedButton.icon(
              onPressed: _viewModel.isLoading ? null : _clearFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear'),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _viewModel.isLoading
                  ? null
                  : () {
                      _viewModel.loadMemberships();
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.memberships.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.memberships.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            Text(_viewModel.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                _viewModel.loadMemberships();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_viewModel.memberships.isEmpty) {
      return const Center(
        child: Text('No memberships match the selected filters.'),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Client')),
                  DataColumn(label: Text('Therapist')),
                  DataColumn(label: Text('Plan')),
                  DataColumn(label: Text('Sessions')),
                  DataColumn(label: Text('Membership status')),
                  DataColumn(label: Text('Payment status')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Expires')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _viewModel.memberships.map(_buildRow).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  DataRow _buildRow(AdminMembershipModel membership) {
    final dateFormatter = DateFormat('dd.MM.yyyy.');

    final progress = membership.totalSessions <= 0
        ? 0.0
        : membership.remainingSessions / membership.totalSessions;

    return DataRow(
      onSelectChanged: (_) {
        _openDetails(membership.id);
      },
      cells: [
        DataCell(Text('#${membership.id}')),
        DataCell(
          _PersonCell(
            name: membership.clientName,
            email: membership.clientEmail,
          ),
        ),
        DataCell(
          _PersonCell(
            name: membership.therapistName,
            email: membership.therapistEmail,
          ),
        ),
        DataCell(Text(_formatPlan(membership.planType))),
        DataCell(
          SizedBox(
            width: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${membership.remainingSessions}'
                  ' / '
                  '${membership.totalSessions}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
              ],
            ),
          ),
        ),
        DataCell(_StatusChip(value: membership.membershipStatus)),
        DataCell(_StatusChip(value: membership.paymentStatus)),
        DataCell(Text('${membership.price.toStringAsFixed(2)} USD')),
        DataCell(
          Text(
            membership.expiresAtUtc == null
                ? '—'
                : dateFormatter.format(membership.expiresAtUtc!.toLocal()),
          ),
        ),
        DataCell(
          IconButton(
            tooltip: 'Open details',
            onPressed: () {
              _openDetails(membership.id);
            },
            icon: const Icon(Icons.visibility),
          ),
        ),
      ],
    );
  }

  void _openDetails(int membershipId) {
    Navigator.of(
      context,
    ).pushNamed(AppRouter.membershipManagementDetails, arguments: membershipId);
  }

  Widget _buildPagination() {
    final displayedPage = _viewModel.totalPages == 0
        ? 0
        : _viewModel.pageNumber;

    return Row(
      children: [
        Text(
          'Page $displayedPage '
          'of ${_viewModel.totalPages}',
        ),
        const Spacer(),
        Text('${_viewModel.totalCount} total'),
        const SizedBox(width: 16),
        IconButton(
          tooltip: 'Previous page',
          onPressed: _viewModel.hasPreviousPage && !_viewModel.isLoading
              ? _viewModel.previousPage
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: _viewModel.hasNextPage && !_viewModel.isLoading
              ? _viewModel.nextPage
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  String _formatPlan(String planType) {
    switch (planType) {
      case 'TenSessions':
        return '10 sessions';

      case 'TwentySessions':
        return '20 sessions';

      case 'ThirtySessions':
        return '30 sessions';

      default:
        return planType;
    }
  }
}

class _PersonCell extends StatelessWidget {
  final String name;

  final String email;

  const _PersonCell({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 170),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            email,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String value;

  const _StatusChip({required this.value});

  @override
  Widget build(BuildContext context) {
    IconData icon;

    switch (value.toLowerCase()) {
      case 'active':
      case 'paid':
      case 'consumed':
        icon = Icons.check_circle;
        break;

      case 'pending':
      case 'pendingpayment':
      case 'refundpending':
      case 'reserved':
        icon = Icons.schedule;
        break;

      case 'restored':
      case 'refunded':
        icon = Icons.replay;
        break;

      case 'expired':
      case 'depleted':
      case 'inactive':
      case 'failed':
      case 'refundfailed':
        icon = Icons.cancel;
        break;

      default:
        icon = Icons.info_outline;
    }

    return Chip(avatar: Icon(icon, size: 17), label: Text(_formatValue(value)));
  }

  String _formatValue(String value) {
    switch (value) {
      case 'PendingPayment':
        return 'Pending payment';

      case 'RefundPending':
        return 'Refund pending';

      case 'RefundFailed':
        return 'Refund failed';

      case 'NotCreated':
        return 'Not created';

      default:
        return value;
    }
  }
}
