class TherapistSpecializationModel {
  final int id;

  final String name;

  final String? description;

  final bool isActive;

  final int therapistCount;

  final DateTime createdAtUtc;

  final DateTime? updatedAtUtc;

  const TherapistSpecializationModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.therapistCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  factory TherapistSpecializationModel.fromJson(Map<String, dynamic> json) {
    return TherapistSpecializationModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      therapistCount: json['therapistCount'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc'] as String),
    );
  }
}
