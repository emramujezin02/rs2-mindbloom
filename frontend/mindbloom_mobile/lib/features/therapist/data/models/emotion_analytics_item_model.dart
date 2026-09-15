class EmotionAnalyticsItemModel {
  final String emotion;
  final int count;
  final double percentage;

  const EmotionAnalyticsItemModel({
    required this.emotion,
    required this.count,
    required this.percentage,
  });

  factory EmotionAnalyticsItemModel.fromJson(Map<String, dynamic> json) {
    return EmotionAnalyticsItemModel(
      emotion: _toString(json['emotion']),
      count: _toInt(json['count']),
      percentage: _toDouble(json['percentage']),
    );
  }

  static String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
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
