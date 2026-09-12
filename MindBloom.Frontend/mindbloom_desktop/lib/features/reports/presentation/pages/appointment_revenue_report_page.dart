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

  static const List<String> _appointmentStatuses = [
    'Pending',
    'Accepted',
    'Rejected',
    'Cancelled',
    'Completed',
  ];

  static const List<String> _appointmentTypes = ['Online', 'InPerson'];

  static const List<String> _paymentStatuses = [
    'Pending',
    'Paid',
    'Failed',
    'Refunded',
    'RefundPending',
    'RefundFailed',
  ];

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createAppointmentRevenueReportViewModel();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.initialize();
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
            AppErrorBanner(message: _viewModel.errorMessage!),
          ],

          if (_viewModel.isLoading) ...[
            const SizedBox(height: 28),
            const AdminTableLoadingState(message: 'Generating report...'),
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
    return AdminPageHeader(
      title: 'Appointment revenue report',
      subtitle: 'Review appointment, payment, refund and revenue data for a selected period.',
      icon: Icons.payments_outlined,
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

            final therapistField = DropdownButtonFormField<int?>(
              initialValue: _viewModel.therapistId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Therapist',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All therapists'),
                ),
                ..._viewModel.therapists.map(
                  (therapist) => DropdownMenuItem<int?>(
                    value: therapist.id,
                    child: Text(
                      therapist.fullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _viewModel.isBusy ? null : _viewModel.setTherapistId,
            );

            final appointmentStatusField = DropdownButtonFormField<String?>(
              initialValue: _viewModel.appointmentStatus,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Appointment status',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All statuses'),
                ),
                ..._appointmentStatuses.map(
                  (status) => DropdownMenuItem<String?>(
                    value: status,
                    child: Text(_formatStatus(status)),
                  ),
                ),
              ],
              onChanged: _viewModel.isBusy
                  ? null
                  : _viewModel.setAppointmentStatus,
            );

            final appointmentTypeField = DropdownButtonFormField<String?>(
              initialValue: _viewModel.appointmentType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Session type',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All session types'),
                ),
                ..._appointmentTypes.map(
                  (type) => DropdownMenuItem<String?>(
                    value: type,
                    child: Text(_formatStatus(type)),
                  ),
                ),
              ],
              onChanged: _viewModel.isBusy
                  ? null
                  : _viewModel.setAppointmentType,
            );

            final paymentStatusField = DropdownButtonFormField<String?>(
              initialValue: _viewModel.paymentStatus,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Payment status',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All payment statuses'),
                ),
                ..._paymentStatuses.map(
                  (status) => DropdownMenuItem<String?>(
                    value: status,
                    child: Text(_formatStatus(status)),
                  ),
                ),
              ],
              onChanged: _viewModel.isBusy ? null : _viewModel.setPaymentStatus,
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

                  const SizedBox(height: 14),

                  therapistField,

                  const SizedBox(height: 14),

                  appointmentStatusField,

                  const SizedBox(height: 14),

                  appointmentTypeField,

                  const SizedBox(height: 14),

                  paymentStatusField,

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _viewModel.isBusy
                              ? null
                              : _viewModel.clearFilters,
                          icon: const Icon(Icons.filter_alt_off),
                          label: const Text('Clear filters'),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(child: generateButton),
                    ],
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(child: appointmentStatusField),

                    const SizedBox(width: 16),

                    Expanded(child: appointmentTypeField),

                    const SizedBox(width: 16),

                    Expanded(child: paymentStatusField),
                  ],
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _viewModel.isBusy
                          ? null
                          : _viewModel.clearFilters,
                      icon: const Icon(Icons.filter_alt_off),
                      label: const Text('Clear filters'),
                    ),

                    const SizedBox(width: 12),

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
                  icon: Icons.check_circle_outline,
                  title: 'Completed',
                  value: report.completedAppointments.toString(),
                  description: 'Completed appointments',
                ),

                _SummaryCard(
                  width: itemWidth,
                  icon: Icons.cancel_outlined,
                  title: 'Cancelled',
                  value: report.cancelledAppointments.toString(),
                  description: 'Cancelled appointments',
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
              const AdminTableEmptyState(
                title: 'No appointment data',
                message: 'No appointment data for the selected period.',
                icon: Icons.event_busy_outlined,
              )
            else
              AdminTableContainer(
                minimumWidth: 620,
                child: DataTable(
                  headingRowHeight: 54,
                  dataRowMinHeight: 58,
                  dataRowMaxHeight: 68,
                  horizontalMargin: 24,
                  columnSpacing: 28,
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
                        DataCell(
                          AdminStatusBadge(
                            label: _formatStatus(item.status),
                            tone: _statusTone(item.status),
                            icon: _statusIcon(item.status),
                          ),
                        ),
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

  AdminStatusTone _statusTone(String value) {
    switch (value.toLowerCase()) {
      case 'completed':
      case 'paid':
        return AdminStatusTone.success;
      case 'pending':
      case 'accepted':
      case 'refundpending':
        return AdminStatusTone.warning;
      case 'cancelled':
      case 'rejected':
      case 'failed':
      case 'refundfailed':
        return AdminStatusTone.danger;
      case 'refunded':
      case 'online':
      case 'inperson':
        return AdminStatusTone.info;
      default:
        return AdminStatusTone.neutral;
    }
  }

  IconData _statusIcon(String value) {
    switch (value.toLowerCase()) {
      case 'completed':
      case 'paid':
        return Icons.check_circle_outline;
      case 'pending':
      case 'accepted':
      case 'refundpending':
        return Icons.schedule;
      case 'cancelled':
      case 'rejected':
      case 'failed':
      case 'refundfailed':
        return Icons.cancel_outlined;
      case 'refunded':
        return Icons.undo;
      default:
        return Icons.info_outline;
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
