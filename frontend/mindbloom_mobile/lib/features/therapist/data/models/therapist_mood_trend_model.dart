import 'emotion_analytics_item_model.dart';
import 'mood_trend_point_model.dart';

class TherapistMoodTrendModel {
  final int clientId;
  final int days;

  final DateTime? fromUtc;
  final DateTime? toUtc;

  final double? averageMood;

  final String? mostFrequentEmotion;

  final int totalEntries;
  final MoodTrendPointModel? bestDay;

  final MoodTrendPointModel? hardestDay;

  final String trend;

  final double? trendDifference;

  final double? previousAverageMood;

  final double? recentAverageMood;

  final List<MoodTrendPointModel> points;

  final List<EmotionAnalyticsItemModel> emotions;

  const TherapistMoodTrendModel({
    required this.clientId,
    required this.days,
    required this.totalEntries,
    required this.trend,
    required this.points,
    required this.emotions,
    this.fromUtc,
    this.toUtc,
    this.averageMood,
    this.mostFrequentEmotion,
    this.trendDifference,
    this.previousAverageMood,
    this.recentAverageMood,
    this.bestDay,
    this.hardestDay,
  });

  factory TherapistMoodTrendModel.fromJson(Map<String, dynamic> json) {
    final pointsValue = json['points'];

    final emotionsValue = json['emotions'];

    final points = pointsValue is List
        ? pointsValue
              .whereType<Map>()
              .map(
                (item) => MoodTrendPointModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <MoodTrendPointModel>[];

    final emotions = emotionsValue is List
        ? emotionsValue
              .whereType<Map>()
              .map(
                (item) => EmotionAnalyticsItemModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <EmotionAnalyticsItemModel>[];

    return TherapistMoodTrendModel(
      clientId: _toInt(json['clientId']),
      days: _toInt(json['days']),
      fromUtc: _toNullableDateTime(json['fromUtc']),
      toUtc: _toNullableDateTime(json['toUtc']),
      averageMood: _toNullableDouble(json['averageMood']),
      mostFrequentEmotion: _toNullableString(json['mostFrequentEmotion']),
      totalEntries: _toInt(json['totalEntries']),
      trend: _toNullableString(json['trend']) ?? 'InsufficientData',
      trendDifference: _toNullableDouble(json['trendDifference']),
      previousAverageMood: _toNullableDouble(json['previousAverageMood']),
      recentAverageMood: _toNullableDouble(json['recentAverageMood']),
      points: points,
      emotions: emotions,
      bestDay: _toNullablePoint(json['bestDay']),
      hardestDay: _toNullablePoint(json['hardestDay']),
    );
  }

  bool get hasData => totalEntries > 0;

  bool get hasTrendData => points.length >= 2 && trend != 'InsufficientData';

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _toNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
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

  static MoodTrendPointModel? _toNullablePoint(dynamic value) {
    if (value is Map<String, dynamic>) {
      return MoodTrendPointModel.fromJson(value);
    }

    if (value is Map) {
      return MoodTrendPointModel.fromJson(Map<String, dynamic>.from(value));
    }

    return null;
  }
}
