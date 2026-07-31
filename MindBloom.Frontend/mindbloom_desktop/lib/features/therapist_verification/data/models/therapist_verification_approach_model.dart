class TherapistVerificationApproachModel {
  final int id;
  final String name;
  final String? description;

  const TherapistVerificationApproachModel({
    required this.id,
    required this.name,
    required this.description,
  });

  factory TherapistVerificationApproachModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TherapistVerificationApproachModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}
