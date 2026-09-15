class AdminAppointmentAuditModel {
  final int id;
  final String? previousStatus;
  final String newStatus;
  final String action;
  final String? reason;
  final int changedByUserId;
  final String changedByUserName;
  final String changedByUserEmail;
  final DateTime changedAtUtc;

  const AdminAppointmentAuditModel({
    required this.id,
    required this.previousStatus,
    required this.newStatus,
    required this.action,
    required this.reason,
    required this.changedByUserId,
    required this.changedByUserName,
    required this.changedByUserEmail,
    required this.changedAtUtc,
  });

  factory AdminAppointmentAuditModel.fromJson(Map<String, dynamic> json) {
    return AdminAppointmentAuditModel(
      id: json['id'] ?? 0,
      previousStatus: json['previousStatus'],
      newStatus: json['newStatus'] ?? '',
      action: json['action'] ?? '',
      reason: json['reason'],
      changedByUserId: json['changedByUserId'] ?? 0,
      changedByUserName: json['changedByUserName'] ?? '',
      changedByUserEmail: json['changedByUserEmail'] ?? '',
      changedAtUtc: DateTime.parse(json['changedAtUtc']),
    );
  }
}
