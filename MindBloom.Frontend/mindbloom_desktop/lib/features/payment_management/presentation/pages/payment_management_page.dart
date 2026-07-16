import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../viewmodels/payment_management_viewmodel.dart';

class PaymentManagementPage extends StatefulWidget {
  const PaymentManagementPage({super.key});

  @override
  State<PaymentManagementPage> createState() => _PaymentManagementPageState();
}

class _PaymentManagementPageState extends State<PaymentManagementPage> {
  final PaymentManagementViewModel _viewModel =
      AppInjection.createPaymentManagementViewModel();

  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _minimumAmountController =
      TextEditingController();

  final TextEditingController _maximumAmountController =
      TextEditingController();

  int? _status;

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
    _minimumAmountController.dispose();
    _maximumAmountController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  double? _parseAmount(TextEditingController controller) {
    final value = controller.text.trim().replaceAll(',', '.');

    if (value.isEmpty) {
      return null;
    }

    return double.tryParse(value);
  }

  Future<void> _applyFilters() {
    return _viewModel.load(
      search: _searchController.text.trim(),
      status: _status,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      minimumAmount: _parseAmount(_minimumAmountController),
      maximumAmount: _parseAmount(_maximumAmountController),
    );
  }

  Future<void> _clearFilters() async {
    _searchController.clear();
    _minimumAmountController.clear();
    _maximumAmountController.clear();

    setState(() {
      _status = null;
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
                  labelText: 'Search ID, client or Stripe reference',
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
              child: DropdownButtonFormField<int?>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All statuses'),
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
                  setState(() {
                    _status = value;
                  });
                },
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _minimumAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Min amount',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _maximumAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Max amount',
                  border: OutlineInputBorder(),
                ),
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
    if (_viewModel.isLoading && _viewModel.payments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.payments.isEmpty) {
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
                onPressed: _viewModel.reload,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_viewModel.payments.isEmpty) {
      return const Center(child: Text('No payments were found.'));
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
                  DataColumn(label: Text('Appointment')),
                  DataColumn(label: Text('Client')),
                  DataColumn(label: Text('Therapist')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Created')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _viewModel.payments
                    .map(
                      (payment) => DataRow(
                        cells: [
                          DataCell(Text(payment.id.toString())),
                          DataCell(Text('#${payment.appointmentId}')),
                          DataCell(
                            Tooltip(
                              message: payment.clientEmail,
                              child: Text(payment.clientName),
                            ),
                          ),
                          DataCell(Text(payment.therapistName)),
                          DataCell(
                            Text(
                              '${payment.amount.toStringAsFixed(2)} '
                              '${payment.currency}',
                            ),
                          ),
                          DataCell(_PaymentStatusChip(status: payment.status)),
                          DataCell(
                            Text(
                              formatter.format(payment.createdAtUtc.toLocal()),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Details',
                                  onPressed: () async {
                                    await Navigator.of(context).pushNamed(
                                      AppRouter.paymentManagementDetails,
                                      arguments: payment.id,
                                    );

                                    await _viewModel.reload();
                                  },
                                  icon: const Icon(Icons.visibility),
                                ),
                                IconButton(
                                  tooltip: 'Receipt',
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.paymentReceipt,
                                      arguments: payment.id,
                                    );
                                  },
                                  icon: const Icon(Icons.receipt_long),
                                ),
                              ],
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
              Text('${_viewModel.totalCount} payments'),
              const Spacer(),
              IconButton(
                onPressed: _viewModel.pageNumber > 1
                    ? _viewModel.previousPage
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Page '
                '${_viewModel.pageNumber} '
                'of '
                '${_viewModel.totalPages}',
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

class _PaymentStatusChip extends StatelessWidget {
  final String status;

  const _PaymentStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    IconData icon;

    if (normalized == 'paid') {
      icon = Icons.check_circle;
    } else if (normalized == 'refunded') {
      icon = Icons.replay;
    } else if (normalized == 'refundpending') {
      icon = Icons.hourglass_top;
    } else if (normalized == 'failed' || normalized == 'refundfailed') {
      icon = Icons.error;
    } else {
      icon = Icons.schedule;
    }

    return Chip(avatar: Icon(icon, size: 18), label: Text(status));
  }
}
