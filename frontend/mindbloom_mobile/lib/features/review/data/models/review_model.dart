class ReviewModel {
  final int id;
  final int? therapistId;
  final int? appointmentId;
  final String clientName;
  final String therapistName;
  final int rating;
  final String comment;
  final DateTime createdAtUtc;

  final bool isApproved;
  final String moderationStatus;
  final bool canEdit;
  final String? moderationReason;

  final String? therapistReply;
  final DateTime? therapistReplyCreatedAtUtc;

  const ReviewModel({
    required this.id,
    this.therapistId,
    this.appointmentId,
    required this.clientName,
    required this.therapistName,
    required this.rating,
    required this.comment,
    required this.createdAtUtc,
    this.isApproved = false,
    this.moderationStatus = '',
    this.canEdit = false,
    this.moderationReason,
    this.therapistReply,
    this.therapistReplyCreatedAtUtc,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final isApproved = _parseBool(json['isApproved']);

    final moderationStatus =
        _parseNullableString(json['moderationStatus']) ??
        (isApproved ? 'Approved' : 'Pending moderation');

    final clientInitials = json['clientInitials']?.toString().trim() ?? '';

    final clientName = json['clientName']?.toString().trim() ?? '';

    return ReviewModel(
      id: _parseInt(json['id']),
      therapistId: _parseNullableInt(json['therapistId']),
      appointmentId: _parseNullableInt(json['appointmentId']),
      clientName: clientInitials.isNotEmpty ? clientInitials : clientName,
      therapistName: json['therapistName']?.toString().trim() ?? '',
      rating: _parseInt(json['rating']),
      comment: json['comment']?.toString().trim() ?? '',
      createdAtUtc: _parseDateTime(json['createdAtUtc']),
      isApproved: isApproved,
      moderationStatus: moderationStatus,
      canEdit: _parseBool(json['canEdit']),
      moderationReason: _parseNullableString(json['moderationReason']),
      therapistReply: _parseNullableString(json['therapistReply']),
      therapistReplyCreatedAtUtc: _parseNullableDateTime(
        json['therapistReplyCreatedAtUtc'],
      ),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    return value?.toString().trim().toLowerCase() == 'true';
  }

  static String? _parseNullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static DateTime _parseDateTime(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}
