class TherapistClientReviewModel {
  final int id;
  final int appointmentId;
  final int rating;
  final String comment;
  final bool isApproved;
  final String moderationStatus;
  final DateTime createdAtUtc;
  final String? therapistReply;
  final DateTime? therapistReplyCreatedAtUtc;

  const TherapistClientReviewModel({
    required this.id,
    required this.appointmentId,
    required this.rating,
    required this.comment,
    required this.isApproved,
    required this.moderationStatus,
    required this.createdAtUtc,
    this.therapistReply,
    this.therapistReplyCreatedAtUtc,
  });

  factory TherapistClientReviewModel.fromJson(Map<String, dynamic> json) {
    return TherapistClientReviewModel(
      id: _toInt(json['id']),
      appointmentId: _toInt(json['appointmentId']),
      rating: _toInt(json['rating']),
      comment: _toString(json['comment']),
      isApproved: _toBool(json['isApproved']),
      moderationStatus: _toString(json['moderationStatus']),
      createdAtUtc:
          _toNullableDateTime(json['createdAtUtc']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      therapistReply: _toNullableString(json['therapistReply']),
      therapistReplyCreatedAtUtc: _toNullableDateTime(
        json['therapistReplyCreatedAtUtc'],
      ),
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

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  static String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? _toNullableString(dynamic value) {
    final parsed = value?.toString().trim();

    if (parsed == null || parsed.isEmpty) {
      return null;
    }

    return parsed;
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}
