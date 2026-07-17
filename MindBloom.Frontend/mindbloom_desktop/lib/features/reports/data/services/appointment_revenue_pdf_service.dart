import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/features/reports/data/models/appointment_revenue_report_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AppointmentRevenuePdfService {
  final DateFormat _dateFormatter = DateFormat('dd.MM.yyyy');

  final DateFormat _dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'bs_BA',
    symbol: 'KM',
    decimalDigits: 2,
  );

  Future<Uint8List> generatePdf(AppointmentRevenueReportModel report) async {
    final document = pw.Document(
      title: 'Appointment Revenue Report',
      author: 'MindBloom',
      subject: 'Appointment and revenue administration report',
      creator: 'MindBloom Desktop',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) {
          return _buildHeader(report);
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'MindBloom administration',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of '
                  '${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            pw.SizedBox(height: 18),

            _buildOverviewSection(report),

            pw.SizedBox(height: 20),

            _buildAppointmentStatusSection(report),

            pw.SizedBox(height: 20),

            _buildPaymentSection(report),

            pw.SizedBox(height: 20),

            _buildRevenueSection(report),

            pw.SizedBox(height: 22),

            _buildReportNote(),
          ];
        },
      ),
    );

    return document.save();
  }

  Future<bool> savePdf({
    required Uint8List bytes,
    required AppointmentRevenueReportModel report,
  }) async {
    final suggestedName = _createFileName(report);

    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF document', extensions: ['pdf']),
      ],
      confirmButtonText: 'Save report',
    );

    if (location == null) {
      return false;
    }

    final file = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: suggestedName,
    );

    await file.saveTo(location.path);

    return true;
  }

  Future<bool> printPdf({
    required Uint8List bytes,
    required AppointmentRevenueReportModel report,
  }) {
    return Printing.layoutPdf(
      name: _createFileName(report),
      onLayout: (_) async => bytes,
    );
  }

  String _createFileName(AppointmentRevenueReportModel report) {
    final from = DateFormat('yyyy-MM-dd').format(report.fromUtc);

    final to = DateFormat('yyyy-MM-dd').format(report.toUtc);

    return 'mindbloom-appointment-revenue-'
        '$from-$to.pdf';
  }

  pw.Widget _buildHeader(AppointmentRevenueReportModel report) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.green700, width: 1.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 42,
            height: 42,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.green700),
            ),
            child: pw.Text(
              'MB',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
          ),

          pw.SizedBox(width: 12),

          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MindBloom',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Appointment and Revenue Report',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Report period',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                '${_dateFormatter.format(report.fromUtc)}'
                ' - '
                '${_dateFormatter.format(report.toUtc)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Generated: '
                '${_dateTimeFormatter.format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildOverviewSection(AppointmentRevenueReportModel report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Report overview'),

        pw.SizedBox(height: 10),

        pw.Row(
          children: [
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Appointments',
                value: report.totalAppointments.toString(),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Unique clients',
                value: report.uniqueClientsCount.toString(),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Therapists',
                value: report.uniqueTherapistsCount.toString(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildAppointmentStatusSection(
    AppointmentRevenueReportModel report,
  ) {
    final items = [...report.appointmentsByStatus]
      ..sort((first, second) => second.count.compareTo(first.count));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Appointments by status'),

        pw.SizedBox(height: 10),

        if (items.isEmpty)
          _buildEmptyMessage('No appointment data is available.')
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Status', 'Number of appointments', 'Share'],
            data: items.map((item) {
              final percentage = report.totalAppointments == 0
                  ? 0.0
                  : item.count / report.totalAppointments * 100;

              return [
                _formatStatus(item.status),
                item.count.toString(),
                '${percentage.toStringAsFixed(1)}%',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 7,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(1),
            },
          ),
      ],
    );
  }

  pw.Widget _buildPaymentSection(AppointmentRevenueReportModel report) {
    final summary = report.paymentSummary;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Payment and refund summary'),

        pw.SizedBox(height: 10),

        pw.TableHelper.fromTextArray(
          headers: const ['Metric', 'Value'],
          data: [
            ['Payment records', summary.totalPaymentRecords.toString()],
            ['Successful payments', summary.paidPaymentsCount.toString()],
            ['Unpaid appointments', summary.unpaidAppointmentsCount.toString()],
            ['Refund requests', summary.refundRequestedCount.toString()],
            ['Completed refunds', summary.refundedPaymentsCount.toString()],
            ['Failed refunds', summary.failedRefundsCount.toString()],
          ],
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 9,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.blueGrey700,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 7,
          ),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1),
          },
        ),
      ],
    );
  }

  pw.Widget _buildRevenueSection(AppointmentRevenueReportModel report) {
    final summary = report.paymentSummary;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Revenue summary'),

        pw.SizedBox(height: 10),

        pw.Row(
          children: [
            pw.Expanded(
              child: _buildRevenueCard(
                title: 'Gross revenue',
                value: _currencyFormatter.format(summary.grossRevenue),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _buildRevenueCard(
                title: 'Refunded amount',
                value: _currencyFormatter.format(summary.refundedAmount),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _buildRevenueCard(
                title: 'Net revenue',
                value: _currencyFormatter.format(summary.netRevenue),
                highlighted: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildMetricCard({required String title, required String value}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildRevenueCard({
    required String title,
    required String value,
    bool highlighted = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: highlighted ? PdfColors.green50 : PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: highlighted ? PdfColors.green700 : PdfColors.grey300,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: highlighted ? PdfColors.green800 : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey900,
      ),
    );
  }

  pw.Widget _buildEmptyMessage(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        message,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }

  pw.Widget _buildReportNote() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        'Note: Revenue is calculated from successful appointment '
        'payments. Because the current payment model does not store '
        'a separate partial refund amount, completed refunds are '
        'treated as full refunds of the original payment.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey800),
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
