class TherapistPerformanceReportItemModel {
  final int therapistId;
  final int userId;
  final String therapistName;
  final String specialization;
  final int totalAppointments;
  final int completedAppointments;
  final int uniqueClientsCount;
  final double grossRevenue;
  final double refundedAmount;
  final double netRevenue;
  final double? averageRating;
  final int reviewCount;

  const TherapistPerformanceReportItemModel({
    required this.therapistId,
    required this.userId,
    required this.therapistName,
    required this.specialization,
    required this.totalAppointments,
    required this.completedAppointments,
    required this.uniqueClientsCount,
    required this.grossRevenue,
    required this.refundedAmount,
    required this.netRevenue,
    required this.averageRating,
    required this.reviewCount,
  });

  factory TherapistPerformanceReportItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TherapistPerformanceReportItemModel(
      therapistId: _toInt(json['therapistId']),
      userId: _toInt(json['userId']),
      therapistName: json['therapistName']?.toString() ?? 'Unknown therapist',
      specialization: json['specialization']?.toString() ?? '',
      totalAppointments: _toInt(json['totalAppointments']),
      completedAppointments: _toInt(json['completedAppointments']),
      uniqueClientsCount: _toInt(json['uniqueClientsCount']),
      grossRevenue: _toDouble(json['grossRevenue']),
      refundedAmount: _toDouble(json['refundedAmount']),
      netRevenue: _toDouble(json['netRevenue']),
      averageRating: _toNullableDouble(json['averageRating']),
      reviewCount: _toInt(json['reviewCount']),
    );
  }

  double get completionRate {
    if (totalAppointments == 0) {
      return 0;
    }

    return completedAppointments / totalAppointments;
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

  static double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _toNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }
}
