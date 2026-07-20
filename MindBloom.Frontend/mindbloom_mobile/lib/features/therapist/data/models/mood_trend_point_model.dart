class MoodTrendPointModel {
  final DateTime dateUtc;
  final double averageMood;
  final int entryCount;

  const MoodTrendPointModel({
    required this.dateUtc,
    required this.averageMood,
    required this.entryCount,
  });

  factory MoodTrendPointModel.fromJson(Map<String, dynamic> json) {
    return MoodTrendPointModel(
      dateUtc: DateTime.parse(json['dateUtc'].toString()),
      averageMood: (json['averageMood'] as num).toDouble(),
      entryCount: (json['entryCount'] as num).toInt(),
    );
  }
}
