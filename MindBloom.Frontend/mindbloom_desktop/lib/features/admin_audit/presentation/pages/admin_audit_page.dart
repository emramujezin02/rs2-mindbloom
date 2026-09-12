import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/core/widgets/admin_page_header.dart';
import 'package:mindbloom_desktop/core/widgets/admin_status_badge.dart';
import 'package:mindbloom_desktop/core/widgets/app_table_pagination.dart';
import 'package:mindbloom_desktop/features/admin_audit/widgets/admin_audit_details_dialog.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/admin_table_action_menu.dart';
import '../../../../core/widgets/admin_table_container.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../data/models/admin_audit_log_model.dart';
import '../viewmodels/admin_audit_viewmodel.dart';

class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  late final AdminAuditViewModel _viewModel;

  final TextEditingController _searchController = TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createAdminAuditViewModel();

    _viewModel.addListener(_onChanged);

    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);

    _viewModel.dispose();
    _searchController.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _viewModel.selectedAdminUserId != null ||
        _viewModel.selectedAction != null ||
        _viewModel.selectedEntityType != null ||
        _viewModel.selectedSuccess != null ||
        _fromDate != null ||
        _toDate != null;
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _fromDate = selected;
    });

    await _applyPeriod();
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _toDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _toDate = selected;
    });

    await _applyPeriod();
  }

  Future<void> _applyPeriod() async {
    if (_fromDate != null && _toDate != null && _fromDate!.isAfter(_toDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datum od ne može biti nakon datuma do.')),
      );

      return;
    }

    final fromUtc = _fromDate == null
        ? null
        : DateTime.utc(_fromDate!.year, _fromDate!.month, _fromDate!.day);

    final toUtc = _toDate == null
        ? null
        : DateTime.utc(
            _toDate!.year,
            _toDate!.month,
            _toDate!.day,
            23,
            59,
            59,
            999,
          );

    await _viewModel.setPeriod(from: fromUtc, to: toUtc);
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    setState(() {
      _fromDate = null;
      _toDate = null;
    });

    await _viewModel.clearFilters();
  }

  Future<void> _openDetails(AdminAuditLogModel audit) {
    return showDialog<void>(
      context: context,
      builder: (_) {
        return AdminAuditDetailsDialog(audit: audit);
      },
    );
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

          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            _buildActiveFilters(),
          ],

          if (_viewModel.errorMessage != null &&
              _viewModel.logs.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppErrorBanner(
              message: _viewModel.errorMessage!,
              onDismiss: _viewModel.clearError,
            ),
          ],

          const SizedBox(height: 16),

          Expanded(child: _buildContent()),

          if (_viewModel.logs.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPagination(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AdminPageHeader(
      title: 'Admin audit',
      subtitle: 'Review important administrative and security actions.',
      icon: Icons.manage_search_outlined,
      trailing: OutlinedButton.icon(
        onPressed: _viewModel.isLoading ? null : _viewModel.refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: EdgeInsets.zero,
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
                enabled: !_viewModel.isLoading,
                onChanged: (value) {
                  setState(() {});

                  _viewModel.updateSearch(value);
                },
                decoration: const InputDecoration(
                  labelText: 'Pretraga',
                  hintText: 'Korisnik, akcija, entitet, correlation ID',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            SizedBox(
              width: 250,
              child: DropdownButtonFormField<int?>(
                initialValue: _viewModel.selectedAdminUserId,
                decoration: const InputDecoration(
                  labelText: 'Administrator',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Svi administratori'),
                  ),
                  ..._viewModel.users.map((user) {
                    return DropdownMenuItem<int?>(
                      value: user.id,
                      child: Text(
                        user.fullName.trim().isEmpty
                            ? user.email
                            : user.fullName,
                      ),
                    );
                  }),
                ],
                onChanged: _viewModel.isLoading
                    ? null
                    : _viewModel.setAdminUser,
              ),
            ),

            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String?>(
                initialValue: _viewModel.selectedAction,
                decoration: const InputDecoration(
                  labelText: 'Vrsta akcije',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sve akcije'),
                  ),
                  ..._viewModel.actions.map((action) {
                    return DropdownMenuItem<String?>(
                      value: action,
                      child: Text(action),
                    );
                  }),
                ],
                onChanged: _viewModel.isLoading ? null : _viewModel.setAction,
              ),
            ),

            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String?>(
                initialValue: _viewModel.selectedEntityType,
                decoration: const InputDecoration(
                  labelText: 'Entitet',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Svi entiteti'),
                  ),
                  ..._viewModel.entityTypes.map((entityType) {
                    return DropdownMenuItem<String?>(
                      value: entityType,
                      child: Text(entityType),
                    );
                  }),
                ],
                onChanged: _viewModel.isLoading
                    ? null
                    : _viewModel.setEntityType,
              ),
            ),

            SizedBox(
              width: 190,
              child: DropdownButtonFormField<bool?>(
                initialValue: _viewModel.selectedSuccess,
                decoration: const InputDecoration(
                  labelText: 'Rezultat',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<bool?>(
                    value: null,
                    child: Text('Svi rezultati'),
                  ),
                  DropdownMenuItem<bool?>(value: true, child: Text('Uspješno')),
                  DropdownMenuItem<bool?>(
                    value: false,
                    child: Text('Neuspješno'),
                  ),
                ],
                onChanged: _viewModel.isLoading ? null : _viewModel.setResult,
              ),
            ),

            OutlinedButton.icon(
              onPressed: _viewModel.isLoading ? null : _pickFromDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _fromDate == null
                    ? 'Datum od'
                    : DateFormat('dd.MM.yyyy.').format(_fromDate!),
              ),
            ),

            OutlinedButton.icon(
              onPressed: _viewModel.isLoading ? null : _pickToDate,
              icon: const Icon(Icons.event),
              label: Text(
                _toDate == null
                    ? 'Datum do'
                    : DateFormat('dd.MM.yyyy.').format(_toDate!),
              ),
            ),

            OutlinedButton.icon(
              onPressed: _viewModel.isLoading ? null : _clearFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Resetuj filtere'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    final chips = <Widget>[];

    if (_searchController.text.trim().isNotEmpty) {
      chips.add(
        Chip(label: Text('Pretraga: ${_searchController.text.trim()}')),
      );
    }

    if (_viewModel.selectedAdminUserId != null) {
      final selected = _viewModel.users
          .where((user) => user.id == _viewModel.selectedAdminUserId)
          .firstOrNull;

      chips.add(
        Chip(
          label: Text(
            'Administrator: ${selected?.fullName ?? _viewModel.selectedAdminUserId}',
          ),
        ),
      );
    }

    if (_viewModel.selectedAction != null) {
      chips.add(Chip(label: Text('Akcija: ${_viewModel.selectedAction}')));
    }

    if (_viewModel.selectedEntityType != null) {
      chips.add(Chip(label: Text('Entitet: ${_viewModel.selectedEntityType}')));
    }

    if (_viewModel.selectedSuccess != null) {
      chips.add(
        Chip(
          label: Text(
            _viewModel.selectedSuccess!
                ? 'Rezultat: Uspješno'
                : 'Rezultat: Neuspješno',
          ),
        ),
      );
    }

    if (_fromDate != null) {
      chips.add(
        Chip(
          label: Text('Od: ${DateFormat('dd.MM.yyyy.').format(_fromDate!)}'),
        ),
      );
    }

    if (_toDate != null) {
      chips.add(
        Chip(label: Text('Do: ${DateFormat('dd.MM.yyyy.').format(_toDate!)}')),
      );
    }

    chips.add(
      ActionChip(
        avatar: const Icon(Icons.filter_alt_off, size: 18),
        label: const Text('Resetuj filtere'),
        onPressed: _viewModel.isLoading ? null : _clearFilters,
      ),
    );

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.logs.isEmpty) {
      return const AdminTableLoadingState(
        message: 'Učitavanje audit zapisa...',
      );
    }

    if (_viewModel.errorMessage != null && _viewModel.logs.isEmpty) {
      return AdminTableErrorState(
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.loadAuditLogs,
      );
    }

    if (_viewModel.logs.isEmpty) {
      return const AdminTableEmptyState(
        icon: Icons.manage_search_outlined,
        title: 'Nema audit zapisa',
        message: 'Nijedan audit zapis ne odgovara odabranim filterima.',
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm:ss');

    return AdminTableContainer(
      minimumWidth: 1750,
      child: DataTable(
        columnSpacing: 28,
        horizontalMargin: 24,
        headingRowHeight: 54,
        dataRowMinHeight: 62,
        dataRowMaxHeight: 76,
        columns: const [
          DataColumn(label: Text('Korisnik')),
          DataColumn(label: Text('Akcija')),
          DataColumn(label: Text('Entitet')),
          DataColumn(label: Text('ID entiteta')),
          DataColumn(label: Text('Datum i vrijeme')),
          DataColumn(label: Text('IP adresa')),
          DataColumn(label: Text('Correlation ID')),
          DataColumn(label: Text('Rezultat')),
          DataColumn(label: Text('HTTP')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: _viewModel.logs.map((audit) {
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 220,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audit.adminName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        audit.adminEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 170,
                  child: Text(audit.action, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 150,
                  child: Text(
                    audit.entityType,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text(audit.entityId ?? '—')),
              DataCell(Text(formatter.format(audit.occurredAtUtc.toLocal()))),
              DataCell(Text(audit.ipAddress ?? '—')),
              DataCell(
                SizedBox(
                  width: 210,
                  child: SelectableText(audit.correlationId, maxLines: 1),
                ),
              ),
              DataCell(
                AdminStatusBadge(
                  label: audit.isSuccessful ? 'Successful' : 'Failed',
                  tone: audit.isSuccessful
                      ? AdminStatusTone.success
                      : AdminStatusTone.danger,
                  icon: audit.isSuccessful ? Icons.check_circle : Icons.error,
                ),
              ),
              DataCell(Text(audit.statusCode.toString())),
              DataCell(
                AdminTableActionMenu<String>(
                  actions: const [
                    AdminTableAction<String>(
                      value: 'details',
                      label: 'Detalji',
                      icon: Icons.visibility_outlined,
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'details') {
                      _openDetails(audit);
                    }
                  },
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPagination() {
    return AdminTablePagination(
      pageNumber: _viewModel.pageNumber,
      pageSize: _viewModel.pageSize,
      totalCount: _viewModel.totalCount,
      totalPages: _viewModel.totalPages,
      isLoading: _viewModel.isLoading,
      onPreviousPage: _viewModel.hasPreviousPage
          ? _viewModel.previousPage
          : null,
      onNextPage: _viewModel.hasNextPage ? _viewModel.nextPage : null,
      onPageSizeChanged: _viewModel.changePageSize,
    );
  }
}
