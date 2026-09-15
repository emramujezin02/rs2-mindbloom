import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/therapist_performance_report_item_model.dart';
import '../models/therapist_performance_report_model.dart';

class TherapistPerformancePdfService {
  final DateFormat _dateFormatter = DateFormat('dd.MM.yyyy');

  final DateFormat _dateTimeFormatter = DateFormat('dd.MM.yyyy HH:mm');

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'bs_BA',
    symbol: 'KM',
    decimalDigits: 2,
  );

  Future<Uint8List> generatePdf({
    required TherapistPerformanceReportModel report,
  }) async {
    final therapists = [...report.therapists]
      ..sort((first, second) => first.rank.compareTo(second.rank));

    final document = pw.Document(
      title: 'Therapist Performance Report',
      author: 'MindBloom',
      subject: 'Therapist performance administration report',
      creator: 'MindBloom Desktop',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(report),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 16),
          _buildAppliedFilters(report),
          pw.SizedBox(height: 18),
          _buildOverviewSection(report),
          pw.SizedBox(height: 20),
          _buildPerformanceTable(therapists),
          pw.SizedBox(height: 18),
          _buildReportNote(),
        ],
      ),
    );

    return document.save();
  }

  Future<bool> savePdf({
    required Uint8List bytes,
    required TherapistPerformanceReportModel report,
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
    required TherapistPerformanceReportModel report,
  }) {
    return Printing.layoutPdf(
      name: _createFileName(report),
      onLayout: (_) async => bytes,
    );
  }

  String _createFileName(TherapistPerformanceReportModel report) {
    final from = DateFormat('yyyy-MM-dd').format(report.fromUtc);

    final to = DateFormat('yyyy-MM-dd').format(report.toUtc);

    if (report.therapistIdFilter != null) {
      return 'mindbloom-therapist-${report.therapistIdFilter}-performance-$from-$to.pdf';
    }

    return 'mindbloom-therapist-performance-$from-$to.pdf';
  }

  pw.Widget _buildHeader(TherapistPerformanceReportModel report) {
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
                  'Therapist Performance Report',
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
                '${_dateFormatter.format(report.fromUtc)} - '
                '${_dateFormatter.format(report.toUtc)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Generated: '
                '${_dateTimeFormatter.format(report.generatedAtUtc.toLocal())}',
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

  pw.Widget _buildFooter(pw.Context context) {
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
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAppliedFilters(TherapistPerformanceReportModel report) {
    final therapist = report.therapistNameFilter ?? 'All therapists';

    final status = report.therapistStatusFilter ?? 'All statuses';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Applied filters'),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _buildFilterValue(
                'Period',
                '${_dateFormatter.format(report.fromUtc)} - '
                    '${_dateFormatter.format(report.toUtc)}',
              ),
              _buildFilterValue('Therapist', therapist),
              _buildFilterValue(
                'Minimum appointments',
                report.minimumAppointmentsFilter.toString(),
              ),
              _buildFilterValue('Therapist status', status),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFilterValue(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _buildOverviewSection(TherapistPerformanceReportModel report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Report overview'),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Therapists',
                value: report.therapistCount.toString(),
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Appointments',
                value: report.totalAppointments.toString(),
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Completed',
                value: report.totalCompletedAppointments.toString(),
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Cancelled',
                value: report.totalCancelledAppointments.toString(),
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Unique clients',
                value: report.totalUniqueClients.toString(),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Gross revenue',
                value: _currencyFormatter.format(report.totalGrossRevenue),
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Refunded amount',
                value: _currencyFormatter.format(report.totalRefundedAmount),
              ),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Net revenue',
                value: _currencyFormatter.format(report.totalNetRevenue),
                highlighted: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPerformanceTable(
    List<TherapistPerformanceReportItemModel> therapists,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Therapist performance ranking'),
        pw.SizedBox(height: 10),
        if (therapists.isEmpty)
          _buildEmptyMessage(
            'No therapist performance data matches the selected filters.',
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              '#',
              'Therapist',
              'Therapy approaches',
              'Appts.',
              'Completed',
              'Cancelled',
              'Completion',
              'Clients',
              'Rating',
              'Reviews',
              'Net revenue',
              'Avg./appt.',
            ],
            data: therapists.map((therapist) {
              return [
                therapist.rank.toString(),
                therapist.therapistName,
                therapist.therapyApproachesLabel,
                therapist.totalAppointments.toString(),
                therapist.completedAppointments.toString(),
                therapist.cancelledAppointments.toString(),
                '${therapist.completionRate.toStringAsFixed(1)}%',
                therapist.uniqueClientsCount.toString(),
                therapist.averageRating?.toStringAsFixed(2) ?? 'No rating',
                therapist.reviewCount.toString(),
                _currencyFormatter.format(therapist.netRevenue),
                _currencyFormatter.format(
                  therapist.averageRevenuePerAppointment,
                ),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 6.5,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
            cellStyle: const pw.TextStyle(fontSize: 6.2),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 5,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.45),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(0.7),
              4: pw.FlexColumnWidth(0.8),
              5: pw.FlexColumnWidth(0.8),
              6: pw.FlexColumnWidth(0.9),
              7: pw.FlexColumnWidth(0.7),
              8: pw.FlexColumnWidth(0.7),
              9: pw.FlexColumnWidth(0.7),
              10: pw.FlexColumnWidth(1.1),
              11: pw.FlexColumnWidth(1.1),
            },
          ),
      ],
    );
  }

  pw.Widget _buildMetricCard({
    required String title,
    required String value,
    bool highlighted = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
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
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            maxLines: 2,
            style: pw.TextStyle(
              fontSize: 11,
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
        'Ranking is calculated from net revenue, followed by completed '
        'appointments and average rating. Completion rate and average revenue '
        'per appointment are calculated on the backend. Therapists with zero '
        'appointments are displayed with zero values when the minimum '
        'appointments filter allows them. Completed refunds are treated as '
        'full refunds because the current payment model does not contain a '
        'separate partial refund amount.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey800),
      ),
    );
  }
}
