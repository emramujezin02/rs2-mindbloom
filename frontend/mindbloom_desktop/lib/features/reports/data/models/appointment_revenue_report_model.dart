import 'package:mindbloom_desktop/features/reports/data/models/appointment_revenue_repost_item_model.dart';

import 'appointment_payment_report_model.dart';
import 'appointment_status_report_item_model.dart';

class AppointmentRevenueReportModel {
  final DateTime fromUtc;
  final DateTime toUtc;

  final DateTime generatedAtUtc;

  final String generatedByAdmin;

  final int? therapistId;

  final String? therapistName;

  final String? appointmentStatusFilter;

  final String? appointmentTypeFilter;

  final String? paymentStatusFilter;

  final int totalAppointments;

  final int completedAppointments;

  final int cancelledAppointments;

  final int uniqueClientsCount;

  final int uniqueTherapistsCount;

  final List<AppointmentStatusReportItemModel> appointmentsByStatus;

  final AppointmentPaymentReportModel paymentSummary;

  final List<AppointmentRevenueReportItemModel> appointments;

  const AppointmentRevenueReportModel({
    required this.fromUtc,
    required this.toUtc,
    required this.generatedAtUtc,
    required this.generatedByAdmin,
    required this.therapistId,
    required this.therapistName,
    required this.appointmentStatusFilter,
    required this.appointmentTypeFilter,
    required this.paymentStatusFilter,
    required this.totalAppointments,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.uniqueClientsCount,
    required this.uniqueTherapistsCount,
    required this.appointmentsByStatus,
    required this.paymentSummary,
    required this.appointments,
  });

  factory AppointmentRevenueReportModel.fromJson(Map<String, dynamic> json) {
    final rawStatuses = json['appointmentsByStatus'];

    final rawPaymentSummary = json['paymentSummary'];

    final rawAppointments = json['appointments'];

    return AppointmentRevenueReportModel(
      fromUtc: DateTime.parse(json['fromUtc'].toString()).toUtc(),

      toUtc: DateTime.parse(json['toUtc'].toString()).toUtc(),

      generatedAtUtc: DateTime.parse(json['generatedAtUtc'].toString()).toUtc(),

      generatedByAdmin: json['generatedByAdmin']?.toString() ?? '',

      therapistId: (json['therapistId'] as num?)?.toInt(),

      therapistName: json['therapistName']?.toString(),

      appointmentStatusFilter: json['appointmentStatusFilter']?.toString(),

      appointmentTypeFilter: json['appointmentTypeFilter']?.toString(),

      paymentStatusFilter: json['paymentStatusFilter']?.toString(),

      totalAppointments: _toInt(json['totalAppointments']),

      completedAppointments: _toInt(json['completedAppointments']),

      cancelledAppointments: _toInt(json['cancelledAppointments']),

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

      appointments: rawAppointments is List
          ? rawAppointments
                .whereType<Map>()
                .map(
                  (item) => AppointmentRevenueReportItemModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
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
