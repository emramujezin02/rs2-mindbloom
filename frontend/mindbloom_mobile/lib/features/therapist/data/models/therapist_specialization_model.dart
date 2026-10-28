class TherapistSpecializationModel {
  final int id;
  final String name;
  const TherapistSpecializationModel({required this.id, required this.name});
  factory TherapistSpecializationModel.fromJson(Map<String, dynamic> json) =>
      TherapistSpecializationModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
      );
}
