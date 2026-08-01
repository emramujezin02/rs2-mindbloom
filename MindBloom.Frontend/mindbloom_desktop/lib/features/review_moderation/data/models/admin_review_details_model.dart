import 'review_moderation_audit_model.dart';

class AdminReviewDetailsModel {
  final int id;

  final int appointmentId;

  final int clientId;

  final String clientName;

  final String clientEmail;

  final int therapistId;

  final String therapistName;

  final String therapistEmail;

  final int rating;

  final String comment;

  final DateTime createdAtUtc;

  final String? therapistReply;

  final DateTime? therapistReplyCreatedAtUtc;

  final bool isDeleted;

  final String? moderationReason;

  final DateTime? moderatedAtUtc;
  final bool isApproved;

  final String moderationStatus;

  final String? moderatedByAdminName;

  final List<ReviewModerationAuditModel> auditHistory;

  const AdminReviewDetailsModel({
    required this.id,
    required this.appointmentId,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.therapistId,
    required this.therapistName,
    required this.therapistEmail,
    required this.rating,
    required this.comment,
    required this.createdAtUtc,
    required this.therapistReply,
    required this.therapistReplyCreatedAtUtc,
    required this.isDeleted,
    required this.moderationReason,
    required this.moderatedAtUtc,
    required this.moderatedByAdminName,
    required this.auditHistory,
    required this.isApproved,
    required this.moderationStatus,
  });

  factory AdminReviewDetailsModel.fromJson(Map<String, dynamic> json) {
    final rawAudit = json['auditHistory'];

    return AdminReviewDetailsModel(
      id: _toInt(json['id']),
      appointmentId: _toInt(json['appointmentId']),
      clientId: _toInt(json['clientId']),
      clientName: json['clientName']?.toString() ?? '',
      clientEmail: json['clientEmail']?.toString() ?? '',
      therapistId: _toInt(json['therapistId']),
      therapistName: json['therapistName']?.toString() ?? '',
      therapistEmail: json['therapistEmail']?.toString() ?? '',
      rating: _toInt(json['rating']),
      comment: json['comment']?.toString() ?? '',
      isApproved: json['isApproved'] == true,

      moderationStatus: json['moderationStatus']?.toString() ?? 'Pending',
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      therapistReply: json['therapistReply']?.toString(),
      therapistReplyCreatedAtUtc: json['therapistReplyCreatedAtUtc'] == null
          ? null
          : DateTime.tryParse(
              json['therapistReplyCreatedAtUtc'].toString(),
            )?.toUtc(),
      isDeleted: json['isDeleted'] == true,
      moderationReason: json['moderationReason']?.toString(),
      moderatedAtUtc: json['moderatedAtUtc'] == null
          ? null
          : DateTime.tryParse(json['moderatedAtUtc'].toString())?.toUtc(),
      moderatedByAdminName: json['moderatedByAdminName']?.toString(),
      auditHistory: rawAudit is List
          ? rawAudit
                .whereType<Map<String, dynamic>>()
                .map(ReviewModerationAuditModel.fromJson)
                .toList()
          : [],
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
