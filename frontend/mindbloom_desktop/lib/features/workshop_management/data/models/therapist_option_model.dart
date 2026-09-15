class TherapistOptionModel {
  final int id;
  final String fullName;
  final String specialization;

  const TherapistOptionModel({
    required this.id,
    required this.fullName,
    required this.specialization,
  });

  factory TherapistOptionModel.fromJson(Map<String, dynamic> json) {
    return TherapistOptionModel(
      id: json['id'] ?? 0,
      fullName: json['fullName'] ?? '',
      specialization: json['specialization'] ?? '',
    );
  }
}
