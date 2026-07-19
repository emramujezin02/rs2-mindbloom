class TherapistDashboardModel {
  final int totalAppointments;
  final int completedAppointments;
  final int pendingAppointments;
  final double averageRating;
  final int totalReviews;
  final double totalEarnings;

  const TherapistDashboardModel({
    required this.totalAppointments,
    required this.completedAppointments,
    required this.pendingAppointments,
    required this.averageRating,
    required this.totalReviews,
    required this.totalEarnings,
  });

  factory TherapistDashboardModel.fromJson(Map<String, dynamic> json) {
    return TherapistDashboardModel(
      totalAppointments: _toInt(json['totalAppointments']),
      completedAppointments: _toInt(json['completedAppointments']),
      pendingAppointments: _toInt(json['pendingAppointments']),
      averageRating: _toDouble(json['averageRating']),
      totalReviews: _toInt(json['totalReviews']),
      totalEarnings: _toDouble(json['totalEarnings']),
    );
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
}
