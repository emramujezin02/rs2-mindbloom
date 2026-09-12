import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/admin_page_header.dart';
import '../../../../core/widgets/admin_status_badge.dart';
import '../../../../core/widgets/admin_table_container.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../data/models/therapist_performance_report_item_model.dart';
import '../viewmodels/therapist_performance_report_viewmodel.dart';

class TherapistPerformanceReportPage extends StatefulWidget {
  const TherapistPerformanceReportPage({super.key});

  @override
  State<TherapistPerformanceReportPage> createState() =>
      _TherapistPerformanceReportPageState();
}

class _TherapistPerformanceReportPageState
    extends State<TherapistPerformanceReportPage> {
  late final TherapistPerformanceReportViewModel _viewModel;

  late final TextEditingController _minimumAppointmentsController;

  final DateFormat _dateFormatter = DateFormat('dd.MM.yyyy');

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'bs_BA',
    symbol: 'KM',
    decimalDigits: 2,
  );

  static const List<String> _therapistStatuses = [
    'Pending',
    'Approved',
    'Rejected',
    'RequiresChanges',
  ];

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createTherapistPerformanceReportViewModel();

    _minimumAppointmentsController = TextEditingController(
      text: _viewModel.minimumAppointments.toString(),
    );

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.loadTherapistOptions();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _minimumAppointmentsController.dispose();

    _viewModel.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectFromDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _viewModel.fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select report start date',
    );

    if (selectedDate != null) {
      _viewModel.setFromDate(selectedDate);
    }
  }

  Future<void> _selectToDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _viewModel.toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select report end date',
    );

    if (selectedDate != null) {
      _viewModel.setToDate(selectedDate);
    }
  }

  Future<void> _loadReport() async {
    FocusScope.of(context).unfocus();

    final success = await _viewModel.loadReport();

    if (!mounted || !success) {
      return;
    }

    final report = _viewModel.report;

    if (report == null) {
      return;
    }

    if (report.therapists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No therapist performance data matches the selected filters.',
          ),
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Therapist performance report generated successfully.'),
      ),
    );
  }

  Future<void> _savePdf() async {
    final saved = await _viewModel.savePdf();

    if (!mounted) {
      return;
    }

    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF report saved successfully.')),
      );
    }
  }

  Future<void> _printPdf() async {
    final printed = await _viewModel.printPdf();

    if (!mounted) {
      return;
    }

    if (!printed && _viewModel.errorMessage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Printing was cancelled.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const PageStorageKey<String>('therapist-performance-report'),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildFilterCard(),
          if (_viewModel.errorMessage != null) ...[
            const SizedBox(height: 16),
            AppErrorBanner(message: _viewModel.errorMessage!),
          ],
          if (_viewModel.isLoading) ...[
            const SizedBox(height: 28),
            const AdminTableLoadingState(message: 'Generating report...'),
          ],
          if (_viewModel.report != null && !_viewModel.isLoading) ...[
            const SizedBox(height: 28),
            if (_viewModel.report!.therapists.isEmpty)
              _buildEmptyState()
            else ...[
              _buildAppliedFilters(),
              const SizedBox(height: 18),
              _buildSummary(),
              const SizedBox(height: 18),
              _buildPerformanceTable(),
            ],
          ],
          if (_viewModel.pdfBytes != null) ...[
            const SizedBox(height: 28),
            _buildPdfPreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AdminPageHeader(
      title: 'Therapist performance report',
      subtitle: 'Review therapist activity, completion rates, ratings, clients and revenue.',
      icon: Icons.insights_outlined,
      trailing: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: _viewModel.pdfBytes == null || _viewModel.isSavingPdf
                ? null
                : _savePdf,
            icon: _viewModel.isSavingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_viewModel.isSavingPdf ? 'Saving...' : 'Download PDF'),
          ),
          FilledButton.icon(
            onPressed: _viewModel.pdfBytes == null || _viewModel.isPrintingPdf
                ? null
                : _printPdf,
            icon: _viewModel.isPrintingPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print),
            label: Text(_viewModel.isPrintingPdf ? 'Opening print...' : 'Print'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report filters',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 1000;

                final fields = [
                  _buildDateField(
                    label: 'From date',
                    value: _viewModel.fromDate,
                    onPressed: _selectFromDate,
                  ),
                  _buildDateField(
                    label: 'To date',
                    value: _viewModel.toDate,
                    onPressed: _selectToDate,
                  ),
                  _buildTherapistDropdown(),
                  _buildMinimumAppointmentsField(),
                  _buildTherapistStatusDropdown(),
                ];

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < fields.length; index++) ...[
                        fields[index],
                        if (index != fields.length - 1)
                          const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 18),
                      _buildGenerateButton(),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 16),
                        Expanded(child: fields[1]),
                        const SizedBox(width: 16),
                        Expanded(child: fields[2]),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: fields[3]),
                        const SizedBox(width: 16),
                        Expanded(child: fields[4]),
                        const SizedBox(width: 20),
                        _buildGenerateButton(),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      onPressed: _viewModel.isBusy ? null : _loadReport,
      icon: _viewModel.isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf),
      label: Text(_viewModel.isLoading ? 'Generating...' : 'Generate report'),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime value,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: _viewModel.isBusy ? null : onPressed,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_month),
        ),
        child: Text(_dateFormatter.format(value)),
      ),
    );
  }

  Widget _buildTherapistDropdown() {
    return DropdownButtonFormField<int?>(
      initialValue: _viewModel.selectedTherapistId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Therapist',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.psychology),
        suffixIcon: _viewModel.isLoadingTherapists
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('All therapists'),
        ),
        ..._viewModel.therapistOptions.map(
          (therapist) => DropdownMenuItem<int?>(
            value: therapist.id,
            child: Text(therapist.fullName, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: _viewModel.isBusy || _viewModel.isLoadingTherapists
          ? null
          : _viewModel.setSelectedTherapistId,
    );
  }

  Widget _buildMinimumAppointmentsField() {
    return TextFormField(
      controller: _minimumAppointmentsController,
      enabled: !_viewModel.isBusy,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Minimum appointments',
        helperText: 'Use 0 to include therapists without appointments.',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.numbers),
      ),
      onChanged: (value) {
        final parsed = int.tryParse(value.trim());

        if (parsed != null) {
          _viewModel.setMinimumAppointments(parsed);
        }
      },
    );
  }

  Widget _buildTherapistStatusDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _viewModel.selectedTherapistStatus,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Therapist status',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.verified_user),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All statuses'),
        ),
        ..._therapistStatuses.map(
          (status) =>
              DropdownMenuItem<String?>(value: status, child: Text(status)),
        ),
      ],
      onChanged: _viewModel.isBusy ? null : _viewModel.setTherapistStatus,
    );
  }

  Widget _buildAppliedFilters() {
    final report = _viewModel.report!;

    final therapist = report.therapistNameFilter ?? 'All therapists';

    final status = report.therapistStatusFilter ?? 'All statuses';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Applied filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                AdminStatusBadge(
                  label:
                      'Period: ${_dateFormatter.format(report.fromUtc)} - ${_dateFormatter.format(report.toUtc)}',
                  tone: AdminStatusTone.info,
                  icon: Icons.date_range,
                ),
                AdminStatusBadge(
                  label: 'Therapist: $therapist',
                  tone: AdminStatusTone.neutral,
                  icon: Icons.psychology,
                ),
                AdminStatusBadge(
                  label:
                      'Minimum appointments: ${report.minimumAppointmentsFilter}',
                  tone: AdminStatusTone.neutral,
                  icon: Icons.numbers,
                ),
                AdminStatusBadge(
                  label: 'Status: $status',
                  tone: _therapistStatusTone(status),
                  icon: _therapistStatusIcon(status),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final report = _viewModel.report!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report preview',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth >= 1200
                ? 4
                : constraints.maxWidth >= 700
                ? 2
                : 1;

            const spacing = 16.0;

            final itemWidth =
                (constraints.maxWidth - ((columnCount - 1) * spacing)) /
                columnCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _SummaryCard(
                  width: itemWidth,
                  icon: Icons.psychology,
                  title: 'Therapists',
                  value: report.therapistCount.toString(),
                  description: 'Therapists matching filters',
                ),
                _SummaryCard(
                  width: itemWidth,
                  icon: Icons.event_note,
                  title: 'Appointments',
                  value: report.totalAppointments.toString(),
                  description:
                      '${report.totalCompletedAppointments} completed, '
                      '${report.totalCancelledAppointments} cancelled',
                ),
                _SummaryCard(
                  width: itemWidth,
                  icon: Icons.people,
                  title: 'Unique clients',
                  value: report.totalUniqueClients.toString(),
                  description: 'Clients in selected results',
                ),
                _SummaryCard(
                  width: itemWidth,
                  icon: Icons.account_balance_wallet,
                  title: 'Net revenue',
                  value: _currencyFormatter.format(report.totalNetRevenue),
                  description:
                      '${_currencyFormatter.format(report.totalGrossRevenue)} gross, '
                      '${_currencyFormatter.format(report.totalRefundedAmount)} refunded',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPerformanceTable() {
    final therapists = _viewModel.report!.therapists;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Therapist performance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            AdminTableContainer(
              minimumWidth: 1500,
              child: DataTable(
                headingRowHeight: 54,
                dataRowMinHeight: 62,
                dataRowMaxHeight: 76,
                horizontalMargin: 24,
                columnSpacing: 28,
                columns: const [
                  DataColumn(numeric: true, label: Text('Rank')),
                  DataColumn(label: Text('Therapist')),
                  DataColumn(label: Text('Therapy approaches')),
                  DataColumn(numeric: true, label: Text('Appointments')),
                  DataColumn(numeric: true, label: Text('Completed')),
                  DataColumn(numeric: true, label: Text('Cancelled')),
                  DataColumn(numeric: true, label: Text('Completion rate')),
                  DataColumn(numeric: true, label: Text('Clients')),
                  DataColumn(numeric: true, label: Text('Rating')),
                  DataColumn(numeric: true, label: Text('Reviews')),
                  DataColumn(numeric: true, label: Text('Net revenue')),
                  DataColumn(
                    numeric: true,
                    label: Text('Avg. revenue / appointment'),
                  ),
                ],
                rows: therapists.map(_buildTherapistRow).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildTherapistRow(TherapistPerformanceReportItemModel therapist) {
    return DataRow(
      cells: [
        DataCell(Text('#${therapist.rank}')),
        DataCell(
          SizedBox(
            width: 210,
            child: Text(
              therapist.therapistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 260,
            child: Text(
              therapist.therapyApproachesLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(therapist.totalAppointments.toString())),
        DataCell(Text(therapist.completedAppointments.toString())),
        DataCell(Text(therapist.cancelledAppointments.toString())),
        DataCell(Text('${therapist.completionRate.toStringAsFixed(1)}%')),
        DataCell(Text(therapist.uniqueClientsCount.toString())),
        DataCell(Text(therapist.averageRating?.toStringAsFixed(2) ?? '—')),
        DataCell(Text(therapist.reviewCount.toString())),
        DataCell(Text(_currencyFormatter.format(therapist.netRevenue))),
        DataCell(
          Text(
            _currencyFormatter.format(therapist.averageRevenuePerAppointment),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const AdminTableEmptyState(
      title: 'No therapist performance data',
      message:
          'No therapists match the selected period and filters. Try changing the therapist, verification status or minimum number of appointments.',
      icon: Icons.insert_chart_outlined,
    );
  }

  Widget _buildPdfPreview() {
    final bytes = _viewModel.pdfBytes!;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'PDF preview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_viewModel.isGeneratingPdf)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    '${(bytes.length / 1024).toStringAsFixed(1)} KB',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 720,
            child: PdfPreview(
              build: (_) async => bytes,
              canChangeOrientation: false,
              canChangePageFormat: false,
              allowPrinting: false,
              allowSharing: false,
              useActions: false,
              initialPageFormat: PdfPageFormat.a4.landscape,
              pdfFileName: 'mindbloom-therapist-performance-report.pdf',
              loadingWidget: const Center(child: CircularProgressIndicator()),
              onError: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'PDF preview could not be displayed.\n$error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AdminStatusTone _therapistStatusTone(String value) {
    switch (value.toLowerCase()) {
      case 'approved':
        return AdminStatusTone.success;
      case 'pending':
      case 'requireschanges':
        return AdminStatusTone.warning;
      case 'rejected':
        return AdminStatusTone.danger;
      case 'all statuses':
        return AdminStatusTone.neutral;
      default:
        return AdminStatusTone.info;
    }
  }

  IconData _therapistStatusIcon(String value) {
    switch (value.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'pending':
      case 'requireschanges':
        return Icons.schedule;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.verified_user_outlined;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String value;
  final String description;

  const _SummaryCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
