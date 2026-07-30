class AdminDashboardModel {
  final DateTime fromUtc;
  final DateTime toUtc;
  final DateTime generatedAtUtc;

  final int totalUsers;
  final int activeClients;
  final int totalTherapists;
  final int verifiedTherapists;
  final int pendingTherapists;

  final int totalAppointments;
  final int todayAppointments;
  final int completedAppointments;
  final int cancelledAppointments;

  final double totalRevenue;
  final double currentMonthRevenue;
  final double periodRevenue;

  final int activeMemberships;
  final int pendingReviews;
  final int publishedArticles;
  final int activeWorkshops;

  final List<AdminDashboardCountItemModel> appointmentsByStatus;
  final List<AdminDashboardMonthlyRevenueItemModel> revenueByMonth;
  final List<AdminDashboardMonthlyCountItemModel> newUsersByMonth;
  final List<AdminDashboardCountItemModel> appointmentsByTherapyApproach;
  final List<AdminDashboardMonthlyCountItemModel> verifiedTherapistsByMonth;

  const AdminDashboardModel({
    required this.fromUtc,
    required this.toUtc,
    required this.generatedAtUtc,
    required this.totalUsers,
    required this.activeClients,
    required this.totalTherapists,
    required this.verifiedTherapists,
    required this.pendingTherapists,
    required this.totalAppointments,
    required this.todayAppointments,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.totalRevenue,
    required this.currentMonthRevenue,
    required this.periodRevenue,
    required this.activeMemberships,
    required this.pendingReviews,
    required this.publishedArticles,
    required this.activeWorkshops,
    required this.appointmentsByStatus,
    required this.revenueByMonth,
    required this.newUsersByMonth,
    required this.appointmentsByTherapyApproach,
    required this.verifiedTherapistsByMonth,
  });

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardModel(
      fromUtc: _toDateTime(json['fromUtc']),
      toUtc: _toDateTime(json['toUtc']),
      generatedAtUtc: _toDateTime(json['generatedAtUtc']),
      totalUsers: _toInt(json['totalUsers']),
      activeClients: _toInt(json['activeClients']),
      totalTherapists: _toInt(json['totalTherapists']),
      verifiedTherapists: _toInt(json['verifiedTherapists']),
      pendingTherapists: _toInt(json['pendingTherapists']),
      totalAppointments: _toInt(json['totalAppointments']),
      todayAppointments: _toInt(json['todayAppointments']),
      completedAppointments: _toInt(json['completedAppointments']),
      cancelledAppointments: _toInt(json['cancelledAppointments']),
      totalRevenue: _toDouble(json['totalRevenue']),
      currentMonthRevenue: _toDouble(json['currentMonthRevenue']),
      periodRevenue: _toDouble(json['periodRevenue']),
      activeMemberships: _toInt(json['activeMemberships']),
      pendingReviews: _toInt(json['pendingReviews']),
      publishedArticles: _toInt(json['publishedArticles']),
      activeWorkshops: _toInt(json['activeWorkshops']),
      appointmentsByTherapyApproach: _toList(
        json['appointmentsByTherapyApproach'],
        AdminDashboardCountItemModel.fromJson,
      ),
      verifiedTherapistsByMonth: _toList(
        json['verifiedTherapistsByMonth'],
        AdminDashboardMonthlyCountItemModel.fromJson,
      ),
      appointmentsByStatus: _toList(
        json['appointmentsByStatus'],
        AdminDashboardCountItemModel.fromJson,
      ),
      revenueByMonth: _toList(
        json['revenueByMonth'],
        AdminDashboardMonthlyRevenueItemModel.fromJson,
      ),
      newUsersByMonth: _toList(
        json['newUsersByMonth'],
        AdminDashboardMonthlyCountItemModel.fromJson,
      ),
    );
  }

  int get otherAppointments {
    final knownAppointments = completedAppointments + cancelledAppointments;

    final remaining = totalAppointments - knownAppointments;

    return remaining < 0 ? 0 : remaining;
  }

  int get rejectedTherapists {
    final remaining = totalTherapists - verifiedTherapists - pendingTherapists;

    return remaining < 0 ? 0 : remaining;
  }

  bool get hasAnyData {
    return totalUsers > 0 ||
        activeClients > 0 ||
        totalTherapists > 0 ||
        totalAppointments > 0 ||
        totalRevenue > 0 ||
        activeMemberships > 0 ||
        pendingReviews > 0 ||
        publishedArticles > 0 ||
        activeWorkshops > 0;
  }

  static List<T> _toList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) mapper,
  ) {
    if (value is! List) {
      return <T>[];
    }

    return value
        .whereType<Map>()
        .map((item) => mapper(Map<String, dynamic>.from(item)))
        .toList();
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

  static DateTime _toDateTime(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class AdminDashboardCountItemModel {
  final String label;
  final int count;

  const AdminDashboardCountItemModel({
    required this.label,
    required this.count,
  });

  factory AdminDashboardCountItemModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardCountItemModel(
      label: json['label']?.toString() ?? '',
      count: AdminDashboardModel._toInt(json['count']),
    );
  }
}

class AdminDashboardMonthlyRevenueItemModel {
  final int year;
  final int month;
  final String label;
  final double revenue;

  const AdminDashboardMonthlyRevenueItemModel({
    required this.year,
    required this.month,
    required this.label,
    required this.revenue,
  });

  factory AdminDashboardMonthlyRevenueItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminDashboardMonthlyRevenueItemModel(
      year: AdminDashboardModel._toInt(json['year']),
      month: AdminDashboardModel._toInt(json['month']),
      label: json['label']?.toString() ?? '',
      revenue: AdminDashboardModel._toDouble(json['revenue']),
    );
  }
}

class AdminDashboardMonthlyCountItemModel {
  final int year;
  final int month;
  final String label;
  final int count;

  const AdminDashboardMonthlyCountItemModel({
    required this.year,
    required this.month,
    required this.label,
    required this.count,
  });

  factory AdminDashboardMonthlyCountItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminDashboardMonthlyCountItemModel(
      year: AdminDashboardModel._toInt(json['year']),
      month: AdminDashboardModel._toInt(json['month']),
      label: json['label']?.toString() ?? '',
      count: AdminDashboardModel._toInt(json['count']),
    );
  }
}
