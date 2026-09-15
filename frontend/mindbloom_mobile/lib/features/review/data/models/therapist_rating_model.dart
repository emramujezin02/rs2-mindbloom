class TherapistRatingModel {
  final int therapistId;
  final double averageRating;
  final int totalReviews;

  const TherapistRatingModel({
    required this.therapistId,
    required this.averageRating,
    required this.totalReviews,
  });

  factory TherapistRatingModel.fromJson(Map<String, dynamic> json) {
    return TherapistRatingModel(
      therapistId: _toInt(json['therapistId']),
      averageRating: _toDouble(json['averageRating']),
      totalReviews: _toInt(json['totalReviews']),
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

  static double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
