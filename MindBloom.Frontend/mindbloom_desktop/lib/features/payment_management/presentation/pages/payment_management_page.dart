import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/core/widgets/app_table_pagination.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/admin_payment_model.dart';
import '../../data/models/payment_route_arguments.dart';
import '../viewmodels/payment_management_viewmodel.dart';
import '../../../../core/widgets/admin_table_action_menu.dart';
import '../../../../core/widgets/admin_table_container.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../../../../core/widgets/app_error_banner.dart';

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
      clearCurrentResults: true,
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
        _selectedPaymentType != null ||
        _dateFrom != null ||
        _dateTo != null ||
        _minimumAmountController.text.trim().isNotEmpty ||
        _maximumAmountController.text.trim().isNotEmpty;
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
          if (_selectedPaymentType != null)
            Chip(label: Text('Tip: $_selectedPaymentType')),
          if (_status != null)
            Chip(label: Text('Status: ${_paymentStatusLabel(_status!)}')),
          if (_minimumAmountController.text.trim().isNotEmpty)
            Chip(label: Text('Min: ${_minimumAmountController.text.trim()}')),
          if (_maximumAmountController.text.trim().isNotEmpty)
            Chip(label: Text('Max: ${_maximumAmountController.text.trim()}')),
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

  String _paymentStatusLabel(int value) {
    switch (value) {
      case 1:
        return 'Na čekanju';
      case 2:
        return 'Plaćeno';
      case 3:
        return 'Neuspjelo';
      case 4:
        return 'Refundirano';
      case 5:
        return 'Refundacija na čekanju';
      case 6:
        return 'Refundacija neuspjela';
      default:
        return value.toString();
    }
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

        if (_viewModel.error != null && _viewModel.payments.isNotEmpty)
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
      return const AdminTableLoadingState(message: 'Učitavanje plaćanja...');
    }

    if (_viewModel.error != null && _viewModel.payments.isEmpty) {
      return AdminTableErrorState(
        message: _viewModel.error!,
        onRetry: _viewModel.reload,
      );
    }

    if (_viewModel.payments.isEmpty) {
      return AdminTableEmptyState(
        icon: Icons.payments_outlined,
        title: _hasActiveFilters ? 'Nema rezultata' : 'Nema plaćanja',
        message: _hasActiveFilters
            ? 'Nijedno plaćanje ne odgovara odabranim filterima.'
            : 'Trenutno nema evidentiranih plaćanja.',
        onResetFilters: _hasActiveFilters ? _clearFilters : null,
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AdminTableContainer(
              minimumWidth: 1450,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Tip plaćanja')),
                  DataColumn(label: Text('Povezana stavka')),
                  DataColumn(label: Text('Svrha')),
                  DataColumn(label: Text('Klijent')),
                  DataColumn(label: Text('Terapeut')),
                  DataColumn(label: Text('Iznos')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Kreirano')),
                  DataColumn(label: Text('Akcije')),
                ],
                rows: _viewModel.payments.map((payment) {
                  return DataRow(
                    cells: [
                      DataCell(Text(payment.id.toString())),
                      DataCell(Text(payment.paymentType)),
                      DataCell(
                        Text(
                          payment.appointmentId != null
                              ? 'Termin #${payment.appointmentId}'
                              : payment.membershipId != null
                              ? 'Članarina #${payment.membershipId}'
                              : '—',
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
                        Text(formatter.format(payment.createdAtUtc.toLocal())),
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
                            AdminTableAction<String>(
                              value: 'receipt',
                              label: 'Potvrda',
                              icon: Icons.receipt_long,
                            ),
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'details':
                                _openDetails(payment);
                                break;

                              case 'receipt':
                                _openReceipt(payment);
                                break;
                            }
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
