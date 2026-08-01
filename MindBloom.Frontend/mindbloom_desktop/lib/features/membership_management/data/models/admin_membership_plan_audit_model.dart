class AdminMembershipPlanAuditModel {
  final int id;
  final String action;
  final String changedByName;
  final String? previousValues;
  final String? newValues;
  final String? reason;
  final DateTime changedAtUtc;

  const AdminMembershipPlanAuditModel({
    required this.id,
    required this.action,
    required this.changedByName,
    required this.previousValues,
    required this.newValues,
    required this.reason,
    required this.changedAtUtc,
  });

  factory AdminMembershipPlanAuditModel.fromJson(Map<String, dynamic> json) {
    return AdminMembershipPlanAuditModel(
      id: json['id'] ?? 0,
      action: json['action']?.toString() ?? '',
      changedByName: json['changedByName']?.toString() ?? '',
      previousValues: json['previousValues']?.toString(),
      newValues: json['newValues']?.toString(),
      reason: json['reason']?.toString(),
      changedAtUtc:
          DateTime.tryParse(json['changedAtUtc']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
