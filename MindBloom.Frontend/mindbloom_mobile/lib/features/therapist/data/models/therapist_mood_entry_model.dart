class TherapistMoodEntryModel {
  final int id;
  final DateTime createdAtUtc;
  final int mood;
  final String emotion;

  const TherapistMoodEntryModel({
    required this.id,
    required this.createdAtUtc,
    required this.mood,
    required this.emotion,
  });

  factory TherapistMoodEntryModel.fromJson(Map<String, dynamic> json) {
    return TherapistMoodEntryModel(
      id: _toInt(json['id']),
      createdAtUtc: DateTime.parse(json['createdAtUtc'].toString()),
      mood: _toInt(json['mood']),
      emotion: json['emotion']?.toString() ?? '',
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
