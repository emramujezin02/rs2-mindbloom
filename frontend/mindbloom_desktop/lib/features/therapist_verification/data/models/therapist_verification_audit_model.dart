class TherapistVerificationAuditModel {
  final int id;
  final String adminName;
  final String previousStatus;
  final String newStatus;
  final String? notes;
  final DateTime changedAtUtc;

  const TherapistVerificationAuditModel({
    required this.id,
    required this.adminName,
    required this.previousStatus,
    required this.newStatus,
    required this.notes,
    required this.changedAtUtc,
  });

  factory TherapistVerificationAuditModel.fromJson(Map<String, dynamic> json) {
    return TherapistVerificationAuditModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      adminName: json['adminName']?.toString() ?? '',
      previousStatus: json['previousStatus']?.toString() ?? '',
      newStatus: json['newStatus']?.toString() ?? '',
      notes: json['notes']?.toString(),
      changedAtUtc:
          DateTime.tryParse(json['changedAtUtc']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
