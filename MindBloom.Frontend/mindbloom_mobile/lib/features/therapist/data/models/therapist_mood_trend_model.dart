import 'mood_trend_point_model.dart';

class TherapistMoodTrendModel {
  final double? averageMood;
  final String? mostFrequentEmotion;
  final int totalEntries;

  final List<MoodTrendPointModel> points;

  const TherapistMoodTrendModel({
    required this.averageMood,
    required this.mostFrequentEmotion,
    required this.totalEntries,
    required this.points,
  });

  factory TherapistMoodTrendModel.fromJson(Map<String, dynamic> json) {
    final items = json['points'] as List? ?? [];

    return TherapistMoodTrendModel(
      averageMood: (json['averageMood'] as num?)?.toDouble(),
      mostFrequentEmotion: json['mostFrequentEmotion']?.toString(),
      totalEntries: (json['totalEntries'] as num).toInt(),
      points: items
          .whereType<Map>()
          .map(
            (e) => MoodTrendPointModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}
