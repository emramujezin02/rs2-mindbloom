import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../viewmodels/appointment_management_viewmodel.dart';

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
      search: _searchController.text.trim(),
      status: _status,
      type: _type,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      isPaid: _isPaid,
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

    await _viewModel.load();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.appointments.isEmpty) {
      return Center(
        child: Text(
          _viewModel.error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_viewModel.appointments.isEmpty) {
      return const Center(child: Text('No appointments were found.'));
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Client')),
                  DataColumn(label: Text('Therapist')),
                  DataColumn(label: Text('Start')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Paid')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _viewModel.appointments
                    .map(
                      (appointment) => DataRow(
                        cells: [
                          DataCell(Text(appointment.id.toString())),
                          DataCell(Text(appointment.clientName)),
                          DataCell(Text(appointment.therapistName)),
                          DataCell(
                            Text(
                              formatter.format(appointment.startUtc.toLocal()),
                            ),
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
                            IconButton(
                              tooltip: 'Details',
                              icon: const Icon(Icons.visibility),
                              onPressed: () async {
                                await Navigator.of(context).pushNamed(
                                  AppRouter.appointmentManagementDetails,
                                  arguments: appointment.id,
                                );

                                await _viewModel.reload();
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('${_viewModel.totalCount} appointments'),
              const Spacer(),
              IconButton(
                onPressed: _viewModel.pageNumber > 1
                    ? _viewModel.previousPage
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Page ${_viewModel.pageNumber} '
                'of ${_viewModel.totalPages}',
              ),
              IconButton(
                onPressed: _viewModel.pageNumber < _viewModel.totalPages
                    ? _viewModel.nextPage
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
