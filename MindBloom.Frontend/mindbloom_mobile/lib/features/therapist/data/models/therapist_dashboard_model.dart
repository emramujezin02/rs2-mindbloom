class TherapistDashboardModel {
  final int todayAppointments;
  final int upcomingAppointments;
  final int totalClients;
  final int newRequests;
  final int unreadMessages;
  final double averageRating;
  final double totalEarnings;
  final int newClients;
  final int activeClients;
  final double averageAppointmentsPerMonth;
  final List<TherapistWorkTrendModel> workTrend;

  const TherapistDashboardModel({
    required this.todayAppointments,
    required this.upcomingAppointments,
    required this.totalClients,
    required this.newRequests,
    required this.unreadMessages,
    required this.averageRating,
    required this.totalEarnings,
    required this.newClients,
    required this.activeClients,
    required this.averageAppointmentsPerMonth,
    required this.workTrend,
  });

  factory TherapistDashboardModel.fromJson(Map<String, dynamic> json) {
    final workTrendJson = json['workTrend'];

    return TherapistDashboardModel(
      todayAppointments: _toInt(json['todayAppointments']),
      upcomingAppointments: _toInt(json['upcomingAppointments']),
      totalClients: _toInt(json['totalClients']),
      newRequests: _toInt(json['newRequests']),
      unreadMessages: _toInt(json['unreadMessages']),
      averageRating: _toDouble(json['averageRating']),
      totalEarnings: _toDouble(json['totalEarnings']),
      newClients: _toInt(json['newClients']),
      activeClients: _toInt(json['activeClients']),
      averageAppointmentsPerMonth: _toDouble(
        json['averageAppointmentsPerMonth'],
      ),
      workTrend: workTrendJson is List
          ? workTrendJson
                .whereType<Map>()
                .map(
                  (item) => TherapistWorkTrendModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
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

class TherapistWorkTrendModel {
  final int year;
  final int month;
  final String label;
  final int completedAppointments;

  const TherapistWorkTrendModel({
    required this.year,
    required this.month,
    required this.label,
    required this.completedAppointments,
  });

  factory TherapistWorkTrendModel.fromJson(Map<String, dynamic> json) {
    return TherapistWorkTrendModel(
      year: _toInt(json['year']),
      month: _toInt(json['month']),
      label: json['label']?.toString() ?? '',
      completedAppointments: _toInt(json['completedAppointments']),
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
}
