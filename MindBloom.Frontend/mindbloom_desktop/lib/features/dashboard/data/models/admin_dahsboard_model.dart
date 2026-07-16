class AdminDashboardModel {
  final int totalUsers;
  final int totalClients;
  final int totalTherapists;

  final int pendingTherapists;
  final int approvedTherapists;
  final int rejectedTherapists;

  final int totalAppointments;
  final int completedAppointments;
  final int pendingAppointments;
  final int cancelledAppointments;

  final int totalReviews;
  final int totalPayments;
  final double totalRevenue;

  const AdminDashboardModel({
    required this.totalUsers,
    required this.totalClients,
    required this.totalTherapists,
    required this.pendingTherapists,
    required this.approvedTherapists,
    required this.rejectedTherapists,
    required this.totalAppointments,
    required this.completedAppointments,
    required this.pendingAppointments,
    required this.cancelledAppointments,
    required this.totalReviews,
    required this.totalPayments,
    required this.totalRevenue,
  });

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardModel(
      totalUsers: _toInt(json['totalUsers']),
      totalClients: _toInt(json['totalClients']),
      totalTherapists: _toInt(json['totalTherapists']),
      pendingTherapists: _toInt(json['pendingTherapists']),
      approvedTherapists: _toInt(json['approvedTherapists']),
      rejectedTherapists: _toInt(json['rejectedTherapists']),
      totalAppointments: _toInt(json['totalAppointments']),
      completedAppointments: _toInt(json['completedAppointments']),
      pendingAppointments: _toInt(json['pendingAppointments']),
      cancelledAppointments: _toInt(json['cancelledAppointments']),
      totalReviews: _toInt(json['totalReviews']),
      totalPayments: _toInt(json['totalPayments']),
      totalRevenue: _toDouble(json['totalRevenue']),
    );
  }

  int get otherAppointments {
    final knownAppointments =
        completedAppointments + pendingAppointments + cancelledAppointments;

    final remaining = totalAppointments - knownAppointments;

    return remaining < 0 ? 0 : remaining;
  }

  int get otherUsers {
    final knownUsers = totalClients + totalTherapists;

    final remaining = totalUsers - knownUsers;

    return remaining < 0 ? 0 : remaining;
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
