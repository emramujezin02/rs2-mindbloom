import 'package:flutter_test/flutter_test.dart';

import 'package:mindbloom_desktop/features/reports/data/models/appointment_payment_report_model.dart';
import 'package:mindbloom_desktop/features/reports/data/models/appointment_revenue_report_model.dart';
import 'package:mindbloom_desktop/features/reports/data/models/appointment_revenue_repost_item_model.dart';
import 'package:mindbloom_desktop/features/reports/data/models/appointment_status_report_item_model.dart';
import 'package:mindbloom_desktop/features/reports/data/services/appointment_revenue_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppointmentRevenuePdfService performance', () {
    test('generatePdf p95 is below performance target', () async {
      const maximumP95Milliseconds = 500.0;

      const warmupIterations = 3;

      const measurementIterations = 20;

      final service = AppointmentRevenuePdfService();

      final appointments = List.generate(10, (index) {
        final start = DateTime.utc(2026, 8, 1 + (index % 20), 10);

        return AppointmentRevenueReportItemModel(
          appointmentId: 1000 + index,
          clientName: 'Performance Client $index',
          therapistName: 'Performance Therapist',
          startUtc: start,
          endUtc: start.add(const Duration(hours: 1)),
          appointmentStatus: 'Completed',
          appointmentType: 'Online',
          price: 50,
          paymentStatus: 'Paid',
          paidAmount: 50,
          refundedAmount: 0,
        );
      });

      final report = AppointmentRevenueReportModel(
        fromUtc: DateTime.utc(2026, 8, 1),
        toUtc: DateTime.utc(2026, 8, 31, 23, 59, 59),
        generatedAtUtc: DateTime.utc(2026, 8, 22, 10),
        generatedByAdmin: 'Performance Administrator',
        therapistId: 10,
        therapistName: 'Performance Therapist',
        appointmentStatusFilter: 'Completed',
        appointmentTypeFilter: 'Online',
        paymentStatusFilter: 'Paid',
        totalAppointments: appointments.length,
        completedAppointments: appointments.length,
        cancelledAppointments: 0,
        uniqueClientsCount: appointments.length,
        uniqueTherapistsCount: 1,
        appointmentsByStatus: [
          AppointmentStatusReportItemModel(
            status: 'Completed',
            count: appointments.length,
          ),
        ],
        paymentSummary: AppointmentPaymentReportModel(
          totalPaymentRecords: appointments.length,
          paidPaymentsCount: appointments.length,
          unpaidAppointmentsCount: 0,
          refundRequestedCount: 0,
          refundedPaymentsCount: 0,
          failedRefundsCount: 0,
          grossRevenue: appointments.length * 50.0,
          refundedAmount: 0,
          netRevenue: appointments.length * 50.0,
        ),
        appointments: appointments,
      );

      Future<void> generate() async {
        final bytes = await service.generatePdf(report);

        expect(bytes, isNotEmpty);

        expect(bytes.take(4).toList(), equals(<int>[0x25, 0x50, 0x44, 0x46]));
      }

      /*
       * Warm-up:
       * font/PDF biblioteka može imati inicijalni
       * setup trošak koji ne pripada steady-state p95.
       */
      for (var index = 0; index < warmupIterations; index++) {
        await generate();
      }

      final measurements = <double>[];

      for (var index = 0; index < measurementIterations; index++) {
        final stopwatch = Stopwatch()..start();

        await generate();

        stopwatch.stop();

        measurements.add(stopwatch.elapsedMicroseconds / 1000.0);
      }

      measurements.sort();

      final percentileIndex = ((measurements.length * 0.95).ceil() - 1).clamp(
        0,
        measurements.length - 1,
      );

      final p95 = measurements[percentileIndex];

      expect(
        p95,
        lessThan(maximumP95Milliseconds),
        reason:
            'PDF performance target failed. '
            'Measured p95: ${p95.toStringAsFixed(2)} ms. '
            'Required p95: < '
            '${maximumP95Milliseconds.toStringAsFixed(0)} ms.',
      );
    });
  });
}
