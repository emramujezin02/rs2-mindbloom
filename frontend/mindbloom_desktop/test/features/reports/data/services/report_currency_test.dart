import 'pdf_text_extractor.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_desktop/features/reports/data/models/appointment_revenue_report_model.dart';
import 'package:mindbloom_desktop/features/reports/data/models/therapist_performance_report_model.dart';
import 'package:mindbloom_desktop/features/reports/data/services/appointment_revenue_pdf_service.dart';
import 'package:mindbloom_desktop/features/reports/data/services/therapist_performance_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Appointment PDF labels paid amounts USD without converting the amounts', () async {
    final report = AppointmentRevenueReportModel.fromJson({
      ..._period,
      'generatedByAdmin': 'Synthetic administrator',
      'totalAppointments': 1,
      'completedAppointments': 1,
      'uniqueClientsCount': 1,
      'uniqueTherapistsCount': 1,
      'appointmentsByStatus': [{'status': 'Completed', 'count': 1}],
      'paymentSummary': {
        'totalPaymentRecords': 1, 'paidPaymentsCount': 1,
        'grossRevenue': 50.5, 'refundedAmount': 10.25, 'netRevenue': 40.25,
      },
      'appointments': [{
        'appointmentId': 1, 'clientName': 'Synthetic client',
        'therapistName': 'Synthetic therapist',
        'startUtc': '2026-10-29T10:00:00Z',
        'endUtc': '2026-10-29T11:00:00Z',
        'appointmentStatus': 'Completed', 'appointmentType': 'Online',
        'price': 50.5, 'paymentStatus': 'Paid', 'paidAmount': 50.5,
        'refundedAmount': 10.25,
      }],
    });
    final bytes = await AppointmentRevenuePdfService().generatePdf(report);
    expect(bytes.take(4), [0x25, 0x50, 0x44, 0x46]);
    _expectCurrencyAndAmounts(extractReportPdfText(bytes));
    expect(report.paymentSummary.grossRevenue, 50.5);
    expect(report.paymentSummary.netRevenue, 40.25);
    expect(report.appointments.single.price, 50.5);
  });

  test('Therapist PDF labels direct receipts USD without converting totals', () async {
    final report = TherapistPerformanceReportModel.fromJson({
      ..._period,
      'therapistCount': 1, 'totalAppointments': 1,
      'totalCompletedAppointments': 1, 'totalUniqueClients': 1,
      'totalGrossRevenue': 50.5, 'totalRefundedAmount': 10.25,
      'totalNetRevenue': 40.25,
      'therapists': [{
        'rank': 1, 'therapistId': 1, 'therapistName': 'Synthetic therapist',
        'totalAppointments': 1, 'completedAppointments': 1,
        'uniqueClientsCount': 1, 'grossRevenue': 50.5,
        'refundedAmount': 10.25, 'netRevenue': 40.25,
        'averageRevenuePerAppointment': 40.25,
      }],
    });
    final bytes = await TherapistPerformancePdfService().generatePdf(report: report);
    expect(bytes.take(4), [0x25, 0x50, 0x44, 0x46]);
    _expectCurrencyAndAmounts(extractReportPdfText(bytes));
    expect(report.totalGrossRevenue, 50.5);
    expect(report.totalRefundedAmount, 10.25);
    expect(report.totalNetRevenue, 40.25);
  });
}

const _period = {
  'fromUtc': '2026-10-01T00:00:00Z',
  'toUtc': '2026-10-31T23:59:59Z',
  'generatedAtUtc': '2026-11-01T10:00:00Z',
};

void _expectCurrencyAndAmounts(String text) {
  expect(text, contains('USD'));
  expect(text, isNot(contains('KM')));
  expect(text, contains('50,50'));
  expect(text, contains('10,25'));
  expect(text, contains('40,25'));
}
