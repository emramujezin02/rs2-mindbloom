import 'therapist_performance_report_item_model.dart';

class TherapistPerformanceReportModel {
  final DateTime fromUtc;
  final DateTime toUtc;
  final DateTime generatedAtUtc;

  final int? therapistIdFilter;
  final String? therapistNameFilter;
  final int minimumAppointmentsFilter;
  final String? therapistStatusFilter;

  final int therapistCount;
  final int totalAppointments;
  final int totalCompletedAppointments;
  final int totalCancelledAppointments;
  final int totalUniqueClients;

  final double totalGrossRevenue;
  final double totalRefundedAmount;
  final double totalNetRevenue;

  final List<TherapistPerformanceReportItemModel> therapists;

  const TherapistPerformanceReportModel({
    required this.fromUtc,
    required this.toUtc,
    required this.generatedAtUtc,
    required this.therapistIdFilter,
    required this.therapistNameFilter,
    required this.minimumAppointmentsFilter,
    required this.therapistStatusFilter,
    required this.therapistCount,
    required this.totalAppointments,
    required this.totalCompletedAppointments,
    required this.totalCancelledAppointments,
    required this.totalUniqueClients,
    required this.totalGrossRevenue,
    required this.totalRefundedAmount,
    required this.totalNetRevenue,
    required this.therapists,
  });

  factory TherapistPerformanceReportModel.fromJson(Map<String, dynamic> json) {
    final rawTherapists = json['therapists'];

    return TherapistPerformanceReportModel(
      fromUtc: DateTime.parse(json['fromUtc'].toString()).toUtc(),
      toUtc: DateTime.parse(json['toUtc'].toString()).toUtc(),
      generatedAtUtc: DateTime.parse(json['generatedAtUtc'].toString()).toUtc(),
      therapistIdFilter: _toNullableInt(json['therapistIdFilter']),
      therapistNameFilter: _toNullableString(json['therapistNameFilter']),
      minimumAppointmentsFilter: _toInt(json['minimumAppointmentsFilter']),
      therapistStatusFilter: _toNullableString(json['therapistStatusFilter']),
      therapistCount: _toInt(json['therapistCount']),
      totalAppointments: _toInt(json['totalAppointments']),
      totalCompletedAppointments: _toInt(json['totalCompletedAppointments']),
      totalCancelledAppointments: _toInt(json['totalCancelledAppointments']),
      totalUniqueClients: _toInt(json['totalUniqueClients']),
      totalGrossRevenue: _toDouble(json['totalGrossRevenue']),
      totalRefundedAmount: _toDouble(json['totalRefundedAmount']),
      totalNetRevenue: _toDouble(json['totalNetRevenue']),
      therapists: rawTherapists is List
          ? rawTherapists
                .whereType<Map>()
                .map(
                  (item) => TherapistPerformanceReportItemModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }

  TherapistPerformanceReportItemModel? therapistById(int therapistId) {
    for (final therapist in therapists) {
      if (therapist.therapistId == therapistId) {
        return therapist;
      }
    }

    return null;
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

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _toNullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}
