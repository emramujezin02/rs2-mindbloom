class TherapistDashboardModel {
  final int todayAppointments;
  final int upcomingAppointments;
  final int totalClients;
  final int newRequests;
  final int unreadMessages;
  final double averageRating;
  final double totalEarnings;

  const TherapistDashboardModel({
    required this.todayAppointments,
    required this.upcomingAppointments,
    required this.totalClients,
    required this.newRequests,
    required this.unreadMessages,
    required this.averageRating,
    required this.totalEarnings,
  });

  factory TherapistDashboardModel.fromJson(Map<String, dynamic> json) {
    return TherapistDashboardModel(
      todayAppointments: _toInt(json['todayAppointments']),
      upcomingAppointments: _toInt(json['upcomingAppointments']),
      totalClients: _toInt(json['totalClients']),
      newRequests: _toInt(json['newRequests']),
      unreadMessages: _toInt(json['unreadMessages']),
      averageRating: _toDouble(json['averageRating']),
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
