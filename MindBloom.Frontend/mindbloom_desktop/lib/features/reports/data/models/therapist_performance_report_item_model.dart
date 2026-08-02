class TherapistPerformanceReportItemModel {
  final int rank;
  final int therapistId;
  final int userId;
  final String therapistName;
  final String specialization;
  final List<String> therapyApproaches;
  final int totalAppointments;
  final int completedAppointments;
  final int cancelledAppointments;
  final double completionRate;
  final int uniqueClientsCount;
  final double? averageRating;
  final int reviewCount;
  final double grossRevenue;
  final double refundedAmount;
  final double netRevenue;
  final double averageRevenuePerAppointment;

  const TherapistPerformanceReportItemModel({
    required this.rank,
    required this.therapistId,
    required this.userId,
    required this.therapistName,
    required this.specialization,
    required this.therapyApproaches,
    required this.totalAppointments,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.completionRate,
    required this.uniqueClientsCount,
    required this.averageRating,
    required this.reviewCount,
    required this.grossRevenue,
    required this.refundedAmount,
    required this.netRevenue,
    required this.averageRevenuePerAppointment,
  });

  factory TherapistPerformanceReportItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawApproaches = json['therapyApproaches'];

    return TherapistPerformanceReportItemModel(
      rank: _toInt(json['rank']),
      therapistId: _toInt(json['therapistId']),
      userId: _toInt(json['userId']),
      therapistName: json['therapistName']?.toString() ?? 'Unknown therapist',
      specialization: json['specialization']?.toString() ?? '',
      therapyApproaches: rawApproaches is List
          ? rawApproaches
                .map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty)
                .toList()
          : const [],
      totalAppointments: _toInt(json['totalAppointments']),
      completedAppointments: _toInt(json['completedAppointments']),
      cancelledAppointments: _toInt(json['cancelledAppointments']),
      completionRate: _toDouble(json['completionRate']),
      uniqueClientsCount: _toInt(json['uniqueClientsCount']),
      averageRating: _toNullableDouble(json['averageRating']),
      reviewCount: _toInt(json['reviewCount']),
      grossRevenue: _toDouble(json['grossRevenue']),
      refundedAmount: _toDouble(json['refundedAmount']),
      netRevenue: _toDouble(json['netRevenue']),
      averageRevenuePerAppointment: _toDouble(
        json['averageRevenuePerAppointment'],
      ),
    );
  }

  String get therapyApproachesLabel {
    if (therapyApproaches.isNotEmpty) {
      return therapyApproaches.join(', ');
    }

    if (specialization.trim().isNotEmpty) {
      return specialization.trim();
    }

    return 'Not specified';
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
