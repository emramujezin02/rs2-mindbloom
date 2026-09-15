class AdminUserAuditModel {
  final int id;
  final String action;
  final String changedByName;
  final String changedByEmail;
  final String? previousValues;
  final String? newValues;
  final String? reason;
  final DateTime changedAtUtc;

  const AdminUserAuditModel({
    required this.id,
    required this.action,
    required this.changedByName,
    required this.changedByEmail,
    this.previousValues,
    this.newValues,
    this.reason,
    required this.changedAtUtc,
  });

  factory AdminUserAuditModel.fromJson(Map<String, dynamic> json) {
    return AdminUserAuditModel(
      id: json['id'] as int? ?? 0,
      action: json['action'] as String? ?? '',
      changedByName: json['changedByName'] as String? ?? '',
      changedByEmail: json['changedByEmail'] as String? ?? '',
      previousValues: json['previousValues'] as String?,
      newValues: json['newValues'] as String?,
      reason: json['reason'] as String?,
      changedAtUtc: DateTime.parse(json['changedAtUtc'] as String),
    );
  }
}
