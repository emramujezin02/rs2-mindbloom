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
      dateUtc: _toDateTime(json['dateUtc']),
      averageMood: _toDouble(json['averageMood']),
      entryCount: _toInt(json['entryCount']),
    );
  }

  static DateTime _toDateTime(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');

    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
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
