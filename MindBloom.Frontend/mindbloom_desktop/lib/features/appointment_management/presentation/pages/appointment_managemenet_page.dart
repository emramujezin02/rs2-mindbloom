import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/core/widgets/app_table_pagination.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../viewmodels/appointment_management_viewmodel.dart';
import '../../../../core/widgets/admin_table_action_menu.dart';
import '../../../../core/widgets/admin_table_container.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../../../../core/widgets/app_error_banner.dart';

class AppointmentManagementPage extends StatefulWidget {
  const AppointmentManagementPage({super.key});

  @override
  State<AppointmentManagementPage> createState() =>
      _AppointmentManagementPageState();
}

class _AppointmentManagementPageState extends State<AppointmentManagementPage> {
  final AppointmentManagementViewModel _viewModel =
      AppInjection.createAppointmentManagementViewModel();

  final TextEditingController _searchController = TextEditingController();

  String? _status;

  String? _type;

  bool? _isPaid;

  DateTime? _dateFrom;

  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);

    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _searchController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _applyFilters() {
    return _viewModel.load(
      requestedPage: 1,
      search: _searchController.text.trim(),
      status: _status,
      type: _type,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      isPaid: _isPaid,
      clearCurrentResults: true,
    );
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    setState(() {
      _status = null;
      _type = null;
      _isPaid = null;
      _dateFrom = null;
      _dateTo = null;
    });

    await _viewModel.load(
      requestedPage: 1,
      search: null,
      status: null,
      type: null,
      dateFrom: null,
      dateTo: null,
      isPaid: null,
      clearCurrentResults: true,
    );
  }

  Future<void> _selectDate({required bool isFrom}) async {
    final initialDate = isFrom
        ? _dateFrom ?? DateTime.now()
        : _dateTo ?? DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      if (isFrom) {
        _dateFrom = selected;
      } else {
        _dateTo = selected;
      }
    });
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _status != null ||
        _type != null ||
        _isPaid != null ||
        _dateFrom != null ||
        _dateTo != null;
  }

  String _appointmentStatusLabel(String status) {
    switch (status) {
      case '0':
        return 'Na čekanju';
      case '1':
        return 'Prihvaćen';
      case '2':
        return 'Odbijen';
      case '3':
        return 'Završen';
      case '4':
        return 'Otkazan';
      default:
        return status;
    }
  }

  String _appointmentTypeLabel(String type) {
    switch (type) {
      case '1':
        return 'Online';
      case '2':
        return 'Uživo';
      default:
        return type;
    }
  }

  Widget _buildActiveFilters() {
    if (!_hasActiveFilters) {
      return const SizedBox.shrink();
    }

    final formatter = DateFormat('dd.MM.yyyy.');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_searchController.text.trim().isNotEmpty)
            Chip(label: Text('Pretraga: ${_searchController.text.trim()}')),
          if (_status != null)
            Chip(label: Text('Status: ${_appointmentStatusLabel(_status!)}')),
          if (_type != null)
            Chip(label: Text('Tip: ${_appointmentTypeLabel(_type!)}')),
          if (_isPaid != null)
            Chip(
              label: Text(
                _isPaid! ? 'Plaćanje: Plaćeno' : 'Plaćanje: Nije plaćeno',
              ),
            ),
          if (_dateFrom != null)
            Chip(label: Text('Od: ${formatter.format(_dateFrom!)}')),
          if (_dateTo != null)
            Chip(label: Text('Do: ${formatter.format(_dateTo!)}')),
          ActionChip(
            avatar: const Icon(Icons.filter_alt_off, size: 18),
            label: const Text('Resetuj filtere'),
            onPressed: _viewModel.isLoading ? null : _clearFilters,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),

        if (_hasActiveFilters) ...[
          _buildActiveFilters(),
          const SizedBox(height: 12),
        ],

        if (_viewModel.error != null && _viewModel.appointments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AppErrorBanner(
              message: _viewModel.error!,
              onDismiss: _viewModel.clearError,
            ),
          ),

        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildFilters() {
    final formatter = DateFormat('dd.MM.yyyy.');

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _searchController,
                onChanged: _viewModel.updateSearch,
                decoration: const InputDecoration(
                  labelText: 'Search client, therapist or ID',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  _applyFilters();
                },
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '0', child: Text('Pending')),
                  DropdownMenuItem(value: '1', child: Text('Accepted')),
                  DropdownMenuItem(value: '2', child: Text('Rejected')),
                  DropdownMenuItem(value: '3', child: Text('Completed')),
                  DropdownMenuItem(value: '4', child: Text('Cancelled')),
                ],
                onChanged: (value) {
                  setState(() {
                    _status = value;
                  });
                },
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('Online')),
                  DropdownMenuItem(value: '2', child: Text('In person')),
                ],
                onChanged: (value) {
                  setState(() {
                    _type = value;
                  });
                },
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<bool?>(
                initialValue: _isPaid,
                decoration: const InputDecoration(
                  labelText: 'Payment',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<bool?>(value: null, child: Text('All')),
                  DropdownMenuItem<bool?>(value: true, child: Text('Paid')),
                  DropdownMenuItem<bool?>(
                    value: false,
                    child: Text('Not paid'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _isPaid = value;
                  });
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                _selectDate(isFrom: true);
              },
              icon: const Icon(Icons.date_range),
              label: Text(
                _dateFrom == null ? 'Date from' : formatter.format(_dateFrom!),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                _selectDate(isFrom: false);
              },
              icon: const Icon(Icons.event),
              label: Text(
                _dateTo == null ? 'Date to' : formatter.format(_dateTo!),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _viewModel.isLoading ? null : _applyFilters,
              icon: const Icon(Icons.filter_alt),
              label: const Text('Apply'),
            ),
            OutlinedButton.icon(
              onPressed: _viewModel.isLoading ? null : _clearFilters,
              icon: const Icon(Icons.clear),
              label: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.appointments.isEmpty) {
      return const AdminTableLoadingState(message: 'Učitavanje termina...');
    }

    if (_viewModel.error != null && _viewModel.appointments.isEmpty) {
      return AdminTableErrorState(
        message: _viewModel.error!,
        onRetry: _viewModel.reload,
      );
    }

    if (_viewModel.appointments.isEmpty) {
      return const AdminTableEmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Nema termina',
        message: 'Nijedan termin ne odgovara odabranim filterima.',
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AdminTableContainer(
              minimumWidth: 1100,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Klijent')),
                  DataColumn(label: Text('Terapeut')),
                  DataColumn(label: Text('Početak')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Tip')),
                  DataColumn(label: Text('Plaćeno')),
                  DataColumn(label: Text('Akcije')),
                ],
                rows: _viewModel.appointments.map((appointment) {
                  return DataRow(
                    cells: [
                      DataCell(Text(appointment.id.toString())),
                      DataCell(Text(appointment.clientName)),
                      DataCell(Text(appointment.therapistName)),
                      DataCell(
                        Text(formatter.format(appointment.startUtc.toLocal())),
                      ),
                      DataCell(Text(appointment.status)),
                      DataCell(Text(appointment.type)),
                      DataCell(
                        Icon(
                          appointment.isPaid
                              ? Icons.check_circle
                              : Icons.cancel,
                        ),
                      ),
                      DataCell(
                        AdminTableActionMenu<String>(
                          enabled: !_viewModel.isLoading,
                          actions: const [
                            AdminTableAction<String>(
                              value: 'details',
                              label: 'Detalji',
                              icon: Icons.visibility_outlined,
                            ),
                          ],
                          onSelected: (value) async {
                            if (value != 'details') {
                              return;
                            }

                            await Navigator.of(context).pushNamed(
                              AppRouter.appointmentManagementDetails,
                              arguments: appointment.id,
                            );

                            if (!mounted) {
                              return;
                            }

                            await _viewModel.reload();
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: AdminTablePagination(
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
          ),
        ),
      ],
    );
  }
}
