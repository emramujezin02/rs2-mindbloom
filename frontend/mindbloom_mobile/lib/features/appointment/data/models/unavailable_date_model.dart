class UnavailableDateModel {
  final int id;
  final DateTime startUtc;
  final DateTime endUtc;
  final String reason;

  const UnavailableDateModel({
    required this.id,
    required this.startUtc,
    required this.endUtc,
    required this.reason,
  });

  factory UnavailableDateModel.fromJson(Map<String, dynamic> json) {
    return UnavailableDateModel(
      id: _readInt(json['id']),
      startUtc: _readDateTime(json['startUtc']),
      endUtc: _readDateTime(json['endUtc']),
      reason: json['reason']?.toString().trim() ?? '',
    );
  }

  DateTime get localStart => startUtc.toLocal();

  DateTime get localEnd => endUtc.toLocal();

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _readDateTime(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
