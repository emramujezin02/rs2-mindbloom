class ReviewModel {
  final int id;
  final int? therapistId;
  final int? appointmentId;
  final String clientName;
  final String therapistName;
  final int rating;
  final String comment;
  final DateTime createdAtUtc;
  final String? therapistReply;
  final DateTime? therapistReplyCreatedAtUtc;

  ReviewModel({
    required this.id,
    this.therapistId,
    this.appointmentId,
    required this.clientName,
    required this.therapistName,
    required this.rating,
    required this.comment,
    required this.createdAtUtc,
    this.therapistReply,
    this.therapistReplyCreatedAtUtc,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: _parseInt(json['id']),
      therapistId: _parseNullableInt(json['therapistId']),
      appointmentId: _parseNullableInt(json['appointmentId']),
      clientName:
          json['clientInitials']?.toString().trim() ??
          json['clientName']?.toString().trim() ??
          '',
      therapistName: json['therapistName']?.toString().trim() ?? '',
      rating: _parseInt(json['rating']),
      comment: json['comment']?.toString().trim() ?? '',
      createdAtUtc: _parseDateTime(json['createdAtUtc']),
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

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
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
