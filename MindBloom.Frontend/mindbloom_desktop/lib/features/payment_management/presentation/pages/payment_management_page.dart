import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/admin_payment_model.dart';
import '../../data/models/payment_route_arguments.dart';
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

  String? _selectedPaymentType;

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

    _viewModel.dispose();

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
      requestedPage: 1,
      search: _searchController.text.trim(),
      status: _status,
      paymentType: _selectedPaymentType,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      minimumAmount: _parseAmount(_minimumAmountController),
      maximumAmount: _parseAmount(_maximumAmountController),
    );
  }

  Future<void> _openDetails(AdminPaymentModel payment) async {
    final result = await Navigator.of(context).pushNamed(
      AppRouter.paymentManagementDetails,
      arguments: PaymentRouteArguments(
        paymentId: payment.id,
        paymentType: payment.paymentType,
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _viewModel.reload();
    }
  }

  Future<void> _openReceipt(AdminPaymentModel payment) async {
    await Navigator.of(context).pushNamed(
      AppRouter.paymentReceipt,
      arguments: PaymentRouteArguments(
        paymentId: payment.id,
        paymentType: payment.paymentType,
      ),
    );
  }

  Future<void> _clearFilters() async {
    _searchController.clear();
    _minimumAmountController.clear();
    _maximumAmountController.clear();

    setState(() {
      _status = null;
      _selectedPaymentType = null;
      _dateFrom = null;
      _dateTo = null;
    });

    await _viewModel.load(
      requestedPage: 1,
      search: null,
      status: null,
      paymentType: null,
      dateFrom: null,
      dateTo: null,
      minimumAmount: null,
      maximumAmount: null,
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
                enabled: !_viewModel.isLoading,
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
                key: ValueKey<int?>(_status),
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
                onChanged: _viewModel.isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _status = value;
                        });
                      },
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String?>(
                key: ValueKey<String?>(_selectedPaymentType),
                initialValue: _selectedPaymentType,
                decoration: const InputDecoration(
                  labelText: 'Payment type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All payment types'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Appointment',
                    child: Text('Appointment'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Membership',
                    child: Text('Membership'),
                  ),
                ],
                onChanged: _viewModel.isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _selectedPaymentType = value;
                        });
                      },
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _minimumAmountController,
                enabled: !_viewModel.isLoading,
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
                enabled: !_viewModel.isLoading,
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
              onPressed: _viewModel.isLoading
                  ? null
                  : () {
                      _selectDate(isFrom: true);
                    },
              icon: const Icon(Icons.date_range),
              label: Text(
                _dateFrom == null ? 'Date from' : formatter.format(_dateFrom!),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _viewModel.isLoading
                  ? null
                  : () {
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _viewModel.reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
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
        if (_viewModel.error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _viewModel.error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Payment type')),
                  DataColumn(label: Text('Related item')),
                  DataColumn(label: Text('Purpose')),
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
                          DataCell(Text(payment.paymentType)),
                          DataCell(
                            Text(
                              payment.appointmentId != null
                                  ? 'Appointment #${payment.appointmentId}'
                                  : payment.membershipId != null
                                  ? 'Membership #${payment.membershipId}'
                                  : '-',
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 190,
                              child: Text(
                                payment.purpose,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
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
                              '${payment.currency.toUpperCase()}',
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
                                  onPressed: _viewModel.isLoading
                                      ? null
                                      : () {
                                          _openDetails(payment);
                                        },
                                  icon: const Icon(Icons.visibility),
                                ),
                                IconButton(
                                  tooltip: 'Receipt',
                                  onPressed: _viewModel.isLoading
                                      ? null
                                      : () {
                                          _openReceipt(payment);
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
                tooltip: 'Previous page',
                onPressed: _viewModel.pageNumber > 1 && !_viewModel.isLoading
                    ? _viewModel.previousPage
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                _viewModel.totalPages == 0
                    ? 'Page 0 of 0'
                    : 'Page ${_viewModel.pageNumber} '
                          'of ${_viewModel.totalPages}',
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed:
                    _viewModel.pageNumber < _viewModel.totalPages &&
                        !_viewModel.isLoading
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
    final normalized = status.trim().toLowerCase();

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
