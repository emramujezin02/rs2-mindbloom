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
    int? therapistId,
  }) async {
    final selectedTherapist = therapistId == null
        ? null
        : report.therapistById(therapistId);

    final therapists = selectedTherapist == null
        ? [...report.therapists]
        : [selectedTherapist];

    therapists.sort(
      (first, second) => second.netRevenue.compareTo(first.netRevenue),
    );

    final document = pw.Document(
      title: 'Therapist Performance Report',
      author: 'MindBloom',
      subject: 'Therapist performance administration report',
      creator: 'MindBloom Desktop',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (context) {
          return _buildHeader(
            report: report,
            selectedTherapist: selectedTherapist,
          );
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
                  'Page ${context.pageNumber} of ${context.pagesCount}',
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
            _buildOverviewSection(
              report: report,
              therapists: therapists,
              selectedTherapist: selectedTherapist,
            ),
            pw.SizedBox(height: 20),
            _buildPerformanceTable(therapists),
            if (selectedTherapist != null) ...[
              pw.SizedBox(height: 20),
              _buildSelectedTherapistDetails(selectedTherapist),
            ],
            pw.SizedBox(height: 20),
            _buildReportNote(),
          ];
        },
      ),
    );

    return document.save();
  }

  Future<bool> savePdf({
    required Uint8List bytes,
    required TherapistPerformanceReportModel report,
    int? therapistId,
  }) async {
    final suggestedName = _createFileName(
      report: report,
      therapistId: therapistId,
    );

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
    int? therapistId,
  }) {
    return Printing.layoutPdf(
      name: _createFileName(report: report, therapistId: therapistId),
      onLayout: (_) async => bytes,
    );
  }

  String _createFileName({
    required TherapistPerformanceReportModel report,
    int? therapistId,
  }) {
    final from = DateFormat('yyyy-MM-dd').format(report.fromUtc);
    final to = DateFormat('yyyy-MM-dd').format(report.toUtc);

    if (therapistId == null) {
      return 'mindbloom-therapist-performance-$from-$to.pdf';
    }

    return 'mindbloom-therapist-$therapistId-performance-$from-$to.pdf';
  }

  pw.Widget _buildHeader({
    required TherapistPerformanceReportModel report,
    required TherapistPerformanceReportItemModel? selectedTherapist,
  }) {
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
                if (selectedTherapist != null) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    selectedTherapist.therapistName,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
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
                'Generated: ${_dateTimeFormatter.format(DateTime.now())}',
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

  pw.Widget _buildOverviewSection({
    required TherapistPerformanceReportModel report,
    required List<TherapistPerformanceReportItemModel> therapists,
    required TherapistPerformanceReportItemModel? selectedTherapist,
  }) {
    final completedAppointments =
        selectedTherapist?.completedAppointments ??
        therapists.fold<int>(
          0,
          (sum, therapist) => sum + therapist.completedAppointments,
        );

    final uniqueClients =
        selectedTherapist?.uniqueClientsCount ?? report.totalUniqueClients;

    final grossRevenue =
        selectedTherapist?.grossRevenue ??
        therapists.fold<double>(
          0,
          (sum, therapist) => sum + therapist.grossRevenue,
        );

    final netRevenue =
        selectedTherapist?.netRevenue ??
        therapists.fold<double>(
          0,
          (sum, therapist) => sum + therapist.netRevenue,
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Report overview'),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildMetricCard(
                title: selectedTherapist == null
                    ? 'Therapists'
                    : 'Selected therapist',
                value: selectedTherapist == null
                    ? therapists.length.toString()
                    : selectedTherapist.therapistName,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Completed appointments',
                value: completedAppointments.toString(),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Unique clients',
                value: uniqueClients.toString(),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Gross revenue',
                value: _currencyFormatter.format(grossRevenue),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Net revenue',
                value: _currencyFormatter.format(netRevenue),
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
        _buildSectionTitle('Therapist performance'),
        pw.SizedBox(height: 10),
        if (therapists.isEmpty)
          _buildEmptyMessage('No therapist performance data is available.')
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'Therapist',
              'Specialization',
              'Appointments',
              'Completed',
              'Clients',
              'Rating',
              'Reviews',
              'Gross revenue',
              'Refunded',
              'Net revenue',
            ],
            data: therapists.map((therapist) {
              return [
                therapist.therapistName,
                therapist.specialization.isEmpty
                    ? 'Not specified'
                    : therapist.specialization,
                therapist.totalAppointments.toString(),
                therapist.completedAppointments.toString(),
                therapist.uniqueClientsCount.toString(),
                therapist.averageRating?.toStringAsFixed(2) ?? 'No rating',
                therapist.reviewCount.toString(),
                _currencyFormatter.format(therapist.grossRevenue),
                _currencyFormatter.format(therapist.refundedAmount),
                _currencyFormatter.format(therapist.netRevenue),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 7.5,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
            cellStyle: const pw.TextStyle(fontSize: 7.3),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 6,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.7),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(0.8),
              5: pw.FlexColumnWidth(0.8),
              6: pw.FlexColumnWidth(0.8),
              7: pw.FlexColumnWidth(1.3),
              8: pw.FlexColumnWidth(1.2),
              9: pw.FlexColumnWidth(1.3),
            },
          ),
      ],
    );
  }

  pw.Widget _buildSelectedTherapistDetails(
    TherapistPerformanceReportItemModel therapist,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Selected therapist details'),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Completion rate',
                value:
                    '${(therapist.completionRate * 100).toStringAsFixed(1)}%',
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Average rating',
                value:
                    therapist.averageRating?.toStringAsFixed(2) ?? 'No rating',
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Reviews',
                value: therapist.reviewCount.toString(),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _buildMetricCard(
                title: 'Refunded amount',
                value: _currencyFormatter.format(therapist.refundedAmount),
              ),
            ),
          ],
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
      padding: const pw.EdgeInsets.all(11),
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
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            maxLines: 2,
            style: pw.TextStyle(
              fontSize: 12,
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
        'Revenue is calculated from successful appointment payments. '
        'Completed refunds are treated as full refunds because the current '
        'payment model does not store a separate partial refund amount.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey800),
      ),
    );
  }
}
