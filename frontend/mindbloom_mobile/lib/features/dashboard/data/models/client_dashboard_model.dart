class ClientDashboardModel {
  final int totalAppointments;
  final int completedAppointments;
  final int pendingAppointments;
  final int cancelledAppointments;
  final int totalTherapistsVisited;
  final double totalSpent;
  final DateTime? lastAppointmentDate;
  final DateTime? nextAppointmentDate;

  ClientDashboardModel({
    required this.totalAppointments,
    required this.completedAppointments,
    required this.pendingAppointments,
    required this.cancelledAppointments,
    required this.totalTherapistsVisited,
    required this.totalSpent,
    this.lastAppointmentDate,
    this.nextAppointmentDate,
  });

  factory ClientDashboardModel.fromJson(Map<String, dynamic> json) {
    return ClientDashboardModel(
      totalAppointments: json['totalAppointments'] ?? 0,
      completedAppointments: json['completedAppointments'] ?? 0,
      pendingAppointments: json['pendingAppointments'] ?? 0,
      cancelledAppointments: json['cancelledAppointments'] ?? 0,
      totalTherapistsVisited: json['totalTherapistsVisited'] ?? 0,
      totalSpent: (json['totalSpent'] ?? 0).toDouble(),
      lastAppointmentDate: json['lastAppointmentDate'] == null
          ? null
          : DateTime.parse(json['lastAppointmentDate']),
      nextAppointmentDate: json['nextAppointmentDate'] == null
          ? null
          : DateTime.parse(json['nextAppointmentDate']),
    );
  }
}
