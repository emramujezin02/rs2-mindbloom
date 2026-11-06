import 'dart:convert';
import 'dart:io';
import 'pdf_text_extractor.dart';
import 'package:mindbloom_desktop/features/reports/data/services/report_pdf_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_desktop/features/reports/data/models/appointment_revenue_report_model.dart';
import 'package:mindbloom_desktop/features/reports/data/models/therapist_performance_report_model.dart';
import 'package:mindbloom_desktop/features/reports/data/services/appointment_revenue_pdf_service.dart';
import 'package:mindbloom_desktop/features/reports/data/services/therapist_performance_pdf_service.dart';

const specimen = 'Čekić, Đurić, Željko, Šarić, ćirilica, č, ć, ž, š, đ';
const glyphs = 'č ć ž š đ Č Ć Ž Š Đ';

class NoExternalHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('External HTTP disabled for isolated PDF QA');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = NoExternalHttp();
  });
  const period = {
    'fromUtc': '2026-11-01T00:00:00Z',
    'toUtc': '2026-11-30T23:59:59Z',
    'generatedAtUtc': '2026-11-06T10:00:00Z',
  };
  for (final unicode in [false, true]) {
    final suffix = unicode ? 'unicode' : 'ascii';
    final name = unicode ? '$specimen | $glyphs' : 'Synthetic ASCII control';
    final appointments = AppointmentRevenueReportModel.fromJson({
      ...period,
      'generatedByAdmin': name,
      'therapistId': 1,
      'therapistName': unicode ? 'Željko Šarić' : 'Synthetic therapist',
      'totalAppointments': 1,
      'completedAppointments': 1,
      'uniqueClientsCount': 1,
      'uniqueTherapistsCount': 1,
      'appointmentsByStatus': [
        {'status': 'Completed', 'count': 1},
      ],
      'paymentSummary': {
        'totalPaymentRecords': 1,
        'paidPaymentsCount': 1,
        'grossRevenue': 50.25,
        'refundedAmount': 0,
        'netRevenue': 50.25,
      },
      'appointments': [
        {
          'appointmentId': 123,
          'clientName': unicode ? 'Čekić Đurić' : 'Synthetic client',
          'therapistName': unicode ? 'Željko Šarić' : 'Synthetic therapist',
          'startUtc': '2026-11-07T09:00:00Z',
          'endUtc': '2026-11-07T10:00:00Z',
          'appointmentStatus': 'Completed',
          'appointmentType': 'Online',
          'price': 50.25,
          'paymentStatus': 'Paid',
          'paidAmount': 50.25,
          'refundedAmount': 0,
        },
      ],
    });
    final therapists = TherapistPerformanceReportModel.fromJson({
      ...period,
      'therapistIdFilter': 1,
      'therapistNameFilter': name,
      'therapistCount': 1,
      'totalAppointments': 1,
      'totalCompletedAppointments': 1,
      'totalUniqueClients': 1,
      'totalGrossRevenue': 50.25,
      'totalRefundedAmount': 0,
      'totalNetRevenue': 50.25,
      'therapists': [
        {
          'rank': 1,
          'therapistId': 1,
          'userId': 999,
          'therapistName': name,
          'specialization': unicode ? glyphs : 'Synthetic specialization',
          'totalAppointments': 1,
          'completedAppointments': 1,
          'completionRate': 100,
          'uniqueClientsCount': 1,
          'averageRating': 4.5,
          'reviewCount': 1,
          'grossRevenue': 50.25,
          'refundedAmount': 0,
          'netRevenue': 50.25,
          'averageRevenuePerAppointment': 50.25,
        },
      ],
    });
    for (final kind in ['appointments', 'therapists']) {
      test('production $kind generator $suffix', () async {
        final bytes = kind == 'appointments'
            ? await AppointmentRevenuePdfService().generatePdf(appointments)
            : await TherapistPerformancePdfService().generatePdf(
                report: therapists,
              );
        final source = latin1.decode(bytes);
        expect(source, startsWith('%PDF-'));
        expect(source.trimRight(), endsWith('%%EOF'));
        expect(
          RegExp(
            r'/FontFile2\s+(\d+) 0 R',
          ).allMatches(source).map((match) => match[1]).toSet().length,
          2,
        );
        expect(RegExp(r'/ToUnicode\b').allMatches(source).length, 2);
        expect(source, contains('Roboto-Regular'));
        expect(source, contains('Roboto-Bold'));
        expect(source, isNot(contains('/Helvetica')));
        final text = extractReportPdfText(bytes);
        expect(text, isNot(contains('\uFFFD')));
        expect(text, isNot(contains('\u25A1')));
        expect(text, contains('USD'));
        expect(text, contains('50,25'));
        if (unicode) {
          for (final rune in glyphs.replaceAll(' ', '').runes) {
            expect(text, contains(String.fromCharCode(rune)));
          }
          for (final word in [
            'Čekić',
            'Đurić',
            'Željko',
            'Šarić',
            'ćirilica',
          ]) {
            expect(text, contains(word));
          }
        } else {
          expect(
            text.replaceAll(RegExp(r'\s'), ''),
            contains('SyntheticASCIIcontrol'),
          );
        }
        expect(appointments.appointments.single.price, 50.25);
        expect(appointments.paymentSummary.netRevenue, 50.25);
        expect(therapists.totalNetRevenue, 50.25);
      });
    }
  }
  test(
    'regular and bold fonts preserve every required glyph independently',
    () async {
      final document = pw.Document(theme: await ReportPdfFonts.loadTheme());
      document.addPage(
        pw.Page(
          build: (_) => pw.Column(
            children: [
              pw.Text(glyphs),
              pw.Text(
                glyphs,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      );
      final text = extractReportPdfText(await document.save());
      for (final rune in glyphs.replaceAll(' ', '').runes) {
        expect(String.fromCharCode(rune).allMatches(text).length, 2);
      }
    },
  );
}
