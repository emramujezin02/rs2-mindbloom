class TherapyApproachModel {
  final int id;

  final String name;

  final String? description;

  final bool isActive;

  final int therapistCount;

  final int clientCount;

  final DateTime createdAtUtc;

  final DateTime? updatedAtUtc;

  const TherapyApproachModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.therapistCount,
    required this.clientCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  factory TherapyApproachModel.fromJson(Map<String, dynamic> json) {
    return TherapyApproachModel(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['isActive'] as bool? ?? false,
      therapistCount: json['therapistCount'] as int? ?? 0,
      clientCount: json['clientCount'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'].toString()),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc'].toString()),
    );
  }
}
