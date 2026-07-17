import 'appointment_payment_report_model.dart';
import 'appointment_status_report_item_model.dart';

class AppointmentRevenueReportModel {
  final DateTime fromUtc;
  final DateTime toUtc;
  final int totalAppointments;
  final int uniqueClientsCount;
  final int uniqueTherapistsCount;
  final List<AppointmentStatusReportItemModel> appointmentsByStatus;
  final AppointmentPaymentReportModel paymentSummary;

  const AppointmentRevenueReportModel({
    required this.fromUtc,
    required this.toUtc,
    required this.totalAppointments,
    required this.uniqueClientsCount,
    required this.uniqueTherapistsCount,
    required this.appointmentsByStatus,
    required this.paymentSummary,
  });

  factory AppointmentRevenueReportModel.fromJson(Map<String, dynamic> json) {
    final rawStatuses = json['appointmentsByStatus'];

    final rawPaymentSummary = json['paymentSummary'];

    return AppointmentRevenueReportModel(
      fromUtc: DateTime.parse(json['fromUtc'].toString()).toUtc(),
      toUtc: DateTime.parse(json['toUtc'].toString()).toUtc(),
      totalAppointments: _toInt(json['totalAppointments']),
      uniqueClientsCount: _toInt(json['uniqueClientsCount']),
      uniqueTherapistsCount: _toInt(json['uniqueTherapistsCount']),
      appointmentsByStatus: rawStatuses is List
          ? rawStatuses
                .whereType<Map>()
                .map(
                  (item) => AppointmentStatusReportItemModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      paymentSummary: AppointmentPaymentReportModel.fromJson(
        rawPaymentSummary is Map
            ? Map<String, dynamic>.from(rawPaymentSummary)
            : const <String, dynamic>{},
      ),
    );
  }

  int countForStatus(String status) {
    for (final item in appointmentsByStatus) {
      if (item.status.toLowerCase() == status.toLowerCase()) {
        return item.count;
      }
    }

    return 0;
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
