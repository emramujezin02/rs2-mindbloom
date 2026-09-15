class ReviewEligibilityModel {
  final int appointmentId;
  final bool canReview;
  final String message;
  final int? existingReviewId;
  final String? moderationStatus;

  const ReviewEligibilityModel({
    required this.appointmentId,
    required this.canReview,
    required this.message,
    this.existingReviewId,
    this.moderationStatus,
  });

  factory ReviewEligibilityModel.fromJson(Map<String, dynamic> json) {
    return ReviewEligibilityModel(
      appointmentId: _toInt(json['appointmentId']),
      canReview: _toBool(json['canReview']),
      message: json['message']?.toString().trim() ?? '',
      existingReviewId: _toNullableInt(json['existingReviewId']),
      moderationStatus: _toNullableString(json['moderationStatus']),
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

  static int? _toNullableInt(dynamic value) {
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

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().trim().toLowerCase() == 'true';
  }

  static String? _toNullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}
