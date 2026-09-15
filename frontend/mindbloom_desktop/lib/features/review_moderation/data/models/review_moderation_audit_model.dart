class ReviewModerationAuditModel {
  final int id;

  final String action;

  final String adminName;

  final String adminEmail;

  final String reason;

  final DateTime performedAtUtc;

  const ReviewModerationAuditModel({
    required this.id,
    required this.action,
    required this.adminName,
    required this.adminEmail,
    required this.reason,
    required this.performedAtUtc,
  });

  factory ReviewModerationAuditModel.fromJson(Map<String, dynamic> json) {
    return ReviewModerationAuditModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      action: json['action']?.toString() ?? '',
      adminName: json['adminName']?.toString() ?? '',
      adminEmail: json['adminEmail']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      performedAtUtc:
          DateTime.tryParse(
            json['performedAtUtc']?.toString() ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
