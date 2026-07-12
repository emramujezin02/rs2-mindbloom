class UnavailableDateModel {
  final int id;
  final DateTime startUtc;
  final DateTime endUtc;
  final String reason;

  UnavailableDateModel({
    required this.id,
    required this.startUtc,
    required this.endUtc,
    required this.reason,
  });

  factory UnavailableDateModel.fromJson(Map<String, dynamic> json) {
    return UnavailableDateModel(
      id: json['id'] ?? 0,
      startUtc: DateTime.parse(json['startUtc']),
      endUtc: DateTime.parse(json['endUtc']),
      reason: json['reason'] ?? '',
    );
  }
}
