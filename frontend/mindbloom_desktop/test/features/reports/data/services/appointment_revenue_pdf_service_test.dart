import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_desktop/features/reports/data/models/appointment_payment_report_model.dart';
import 'package:mindbloom_desktop/features/reports/data/models/appointment_revenue_report_model.dart';
import 'package:mindbloom_desktop/features/reports/data/models/appointment_revenue_repost_item_model.dart';
import 'package:mindbloom_desktop/features/reports/data/models/appointment_status_report_item_model.dart';
import 'package:mindbloom_desktop/features/reports/data/services/appointment_revenue_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppointmentRevenuePdfService', () {
    test('generatePdf_WithValidReport_ReturnsPdfBytes', () async {
      final service = AppointmentRevenuePdfService();

      final report = AppointmentRevenueReportModel(
        fromUtc: DateTime.utc(2026, 8, 1),
        toUtc: DateTime.utc(2026, 8, 31, 23, 59, 59),
        generatedAtUtc: DateTime.utc(2026, 8, 22, 10),
        generatedByAdmin: 'E2E Administrator',
        therapistId: 10,
        therapistName: 'E2E Therapist',
        appointmentStatusFilter: 'Completed',
        appointmentTypeFilter: 'Online',
        paymentStatusFilter: 'Paid',
        totalAppointments: 1,
        completedAppointments: 1,
        cancelledAppointments: 0,
        uniqueClientsCount: 1,
        uniqueTherapistsCount: 1,
        appointmentsByStatus: const [
          AppointmentStatusReportItemModel(status: 'Completed', count: 1),
        ],
        paymentSummary: const AppointmentPaymentReportModel(
          totalPaymentRecords: 1,
          paidPaymentsCount: 1,
          unpaidAppointmentsCount: 0,
          refundRequestedCount: 0,
          refundedPaymentsCount: 0,
          failedRefundsCount: 0,
          grossRevenue: 50,
          refundedAmount: 0,
          netRevenue: 50,
        ),
        appointments: [
          AppointmentRevenueReportItemModel(
            appointmentId: 100,
            clientName: 'E2E Client',
            therapistName: 'E2E Therapist',
            startUtc: DateTime.utc(2026, 8, 15, 10),
            endUtc: DateTime.utc(2026, 8, 15, 11),
            appointmentStatus: 'Completed',
            appointmentType: 'Online',
            price: 50,
            paymentStatus: 'Paid',
            paidAmount: 50,
            refundedAmount: 0,
          ),
        ],
      );

      final bytes = await service.generatePdf(report);

      expect(bytes, isNotEmpty);

      expect(bytes.length, greaterThan(100));

      expect(bytes.take(4).toList(), equals(<int>[0x25, 0x50, 0x44, 0x46]));
    });
  });
}
