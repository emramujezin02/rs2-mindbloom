import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../app/di/injection.dart';
import '../../data/models/appointment_revenue_report_model.dart';
import '../viewmodels/appointment_revenue_report_viewmodel.dart';

class AppointmentRevenueReportPage extends StatefulWidget {
  const AppointmentRevenueReportPage({super.key});

  @override
  State<AppointmentRevenueReportPage> createState() =>
      _AppointmentRevenueReportPageState();
}

class _AppointmentRevenueReportPageState
    extends State<AppointmentRevenueReportPage> {
  late final AppointmentRevenueReportViewModel _viewModel;

  final DateFormat _dateFormatter = DateFormat('dd.MM.yyyy');

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'bs_BA',
    symbol: 'KM',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createAppointmentRevenueReportViewModel();

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
      const SnackBar(content: Text('Report generated successfully.')),
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
      key: const PageStorageKey<String>('appointment-revenue-report'),
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
            _buildSummary(_viewModel.report!),
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
              'Appointment revenue report',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Review appointment, payment, refund and '
              'revenue data for a selected period.',
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
            final compact = constraints.maxWidth < 760;

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

  Widget _buildSummary(AppointmentRevenueReportModel report) {
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
                  icon: Icons.calendar_month,
                  title: 'Appointments',
                  value: report.totalAppointments.toString(),
                  description: '${report.uniqueClientsCount} unique clients',
                ),
                _SummaryCard(
                  width: itemWidth,
                  icon: Icons.payments,
                  title: 'Gross revenue',
                  value: _currencyFormatter.format(
                    report.paymentSummary.grossRevenue,
                  ),
                  description:
                      '${report.paymentSummary.paidPaymentsCount} successful payments',
                ),
                _SummaryCard(
                  width: itemWidth,
                  icon: Icons.undo,
                  title: 'Refunded',
                  value: _currencyFormatter.format(
                    report.paymentSummary.refundedAmount,
                  ),
                  description:
                      '${report.paymentSummary.refundedPaymentsCount} completed refunds',
                ),
                _SummaryCard(
                  width: itemWidth,
                  icon: Icons.account_balance_wallet,
                  title: 'Net revenue',
                  value: _currencyFormatter.format(
                    report.paymentSummary.netRevenue,
                  ),
                  description: '${report.uniqueTherapistsCount} therapists',
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 18),

        _buildStatusTable(report),
      ],
    );
  }

  Widget _buildStatusTable(AppointmentRevenueReportModel report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appointments by status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 18),

            if (report.appointmentsByStatus.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No appointment data for the selected period.'),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Status')),
                    DataColumn(numeric: true, label: Text('Count')),
                    DataColumn(numeric: true, label: Text('Share')),
                  ],
                  rows: report.appointmentsByStatus.map((item) {
                    final percentage = report.totalAppointments == 0
                        ? 0.0
                        : item.count / report.totalAppointments * 100;

                    return DataRow(
                      cells: [
                        DataCell(Text(_formatStatus(item.status))),
                        DataCell(Text(item.count.toString())),
                        DataCell(Text('${percentage.toStringAsFixed(1)}%')),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
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
              initialPageFormat: PdfPageFormat.a4,
              pdfFileName: 'mindbloom-appointment-revenue-report.pdf',
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

  String _formatStatus(String value) {
    if (value.trim().isEmpty) {
      return 'Unknown';
    }

    final normalized = value
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('_', ' ')
        .trim();

    if (normalized.isEmpty) {
      return 'Unknown';
    }

    return normalized[0].toUpperCase() + normalized.substring(1);
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
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
