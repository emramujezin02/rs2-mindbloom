class OccupiedSlotModel {
  final DateTime startUtc;
  final DateTime endUtc;

  OccupiedSlotModel({required this.startUtc, required this.endUtc});

  factory OccupiedSlotModel.fromJson(Map<String, dynamic> json) {
    return OccupiedSlotModel(
      startUtc: DateTime.parse(json['startUtc']),
      endUtc: DateTime.parse(json['endUtc']),
    );
  }
}
