import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../app/di/injection.dart';
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

  final DateFormat _dateFormatter = DateFormat('dd.MM.yyyy');

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'bs_BA',
    symbol: 'KM',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createTherapistPerformanceReportViewModel();
    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
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
    final success = await _viewModel.loadReport();

    if (!mounted || !success) {
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
            _buildErrorMessage(_viewModel.errorMessage!),
          ],
          if (_viewModel.isLoading) ...[
            const SizedBox(height: 28),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_viewModel.report != null) ...[
            const SizedBox(height: 28),
            _buildSummary(),
            const SizedBox(height: 18),
            _buildPerformanceTable(),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Therapist performance report',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Review therapist activity, ratings, clients and revenue.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
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
              label: Text(
                _viewModel.isSavingPdf ? 'Saving...' : 'Download PDF',
              ),
            ),
            ElevatedButton.icon(
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
              label: Text(
                _viewModel.isPrintingPdf ? 'Opening print...' : 'Print',
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 18), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 20),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;

            final fromField = _buildDateField(
              label: 'From date',
              value: _viewModel.fromDate,
              onPressed: _selectFromDate,
            );

            final toField = _buildDateField(
              label: 'To date',
              value: _viewModel.toDate,
              onPressed: _selectToDate,
            );

            final therapistField = _buildTherapistDropdown();

            final generateButton = ElevatedButton.icon(
              onPressed: _viewModel.isBusy ? null : _loadReport,
              icon: _viewModel.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(
                _viewModel.isLoading ? 'Generating...' : 'Generate report',
              ),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Report filters',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  fromField,
                  const SizedBox(height: 14),
                  toField,
                  const SizedBox(height: 14),
                  therapistField,
                  const SizedBox(height: 18),
                  generateButton,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report filters',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: fromField),
                    const SizedBox(width: 16),
                    Expanded(child: toField),
                    const SizedBox(width: 16),
                    Expanded(child: therapistField),
                    const SizedBox(width: 20),
                    generateButton,
                  ],
                ),
              ],
            );
          },
        ),
      ),
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
    final therapists = _viewModel.therapists;

    return DropdownButtonFormField<int?>(
      initialValue: _viewModel.selectedTherapistId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Therapist',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.psychology),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('All therapists'),
        ),
        ...therapists.map(
          (therapist) => DropdownMenuItem<int?>(
            value: therapist.therapistId,
            child: Text(
              therapist.therapistName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: _viewModel.report == null || _viewModel.isBusy
          ? null
          : (value) {
              _viewModel.setSelectedTherapistId(value);
            },
    );
  }

  Widget _buildSummary() {
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
                  title: _viewModel.selectedTherapist == null
                      ? 'Therapists'
                      : 'Selected therapist',
                  value:
                      _viewModel.selectedTherapist?.therapistName ??
                      _viewModel.visibleTherapists.length.toString(),
                  description:
                      _viewModel.selectedTherapist?.specialization ??
                      'Therapists included in report',
                ),
                _SummaryCard(
                  width: itemWidth,
                  icon: Icons.check_circle,
                  title: 'Completed appointments',
                  value: _viewModel.displayedCompletedAppointments.toString(),
                  description:
                      '${_viewModel.displayedUniqueClients} unique clients',
                ),
                _SummaryCard(
                  width: itemWidth,
                  icon: Icons.payments,
                  title: 'Gross revenue',
                  value: _currencyFormatter.format(
                    _viewModel.displayedGrossRevenue,
                  ),
                  description: _viewModel.displayedRefundedAmount == 0
                      ? 'No completed refunds'
                      : '${_currencyFormatter.format(_viewModel.displayedRefundedAmount)} refunded',
                ),
                _SummaryCard(
                  width: itemWidth,
                  icon: Icons.account_balance_wallet,
                  title: 'Net revenue',
                  value: _currencyFormatter.format(
                    _viewModel.displayedNetRevenue,
                  ),
                  description: 'Revenue after completed refunds',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPerformanceTable() {
    final therapists = [..._viewModel.visibleTherapists]
      ..sort((first, second) => second.netRevenue.compareTo(first.netRevenue));

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
            if (therapists.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No therapist performance data for the selected period.',
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Therapist')),
                    DataColumn(label: Text('Specialization')),
                    DataColumn(numeric: true, label: Text('Appointments')),
                    DataColumn(numeric: true, label: Text('Completed')),
                    DataColumn(numeric: true, label: Text('Clients')),
                    DataColumn(numeric: true, label: Text('Rating')),
                    DataColumn(numeric: true, label: Text('Reviews')),
                    DataColumn(numeric: true, label: Text('Net revenue')),
                  ],
                  rows: therapists
                      .map((therapist) => _buildTherapistRow(therapist))
                      .toList(),
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
        DataCell(Text(therapist.therapistName)),
        DataCell(
          Text(
            therapist.specialization.isEmpty
                ? 'Not specified'
                : therapist.specialization,
          ),
        ),
        DataCell(Text(therapist.totalAppointments.toString())),
        DataCell(Text(therapist.completedAppointments.toString())),
        DataCell(Text(therapist.uniqueClientsCount.toString())),
        DataCell(Text(therapist.averageRating?.toStringAsFixed(2) ?? '—')),
        DataCell(Text(therapist.reviewCount.toString())),
        DataCell(Text(_currencyFormatter.format(therapist.netRevenue))),
      ],
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

  Widget _buildErrorMessage(String message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
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
