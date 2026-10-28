class TherapistLocationModel {
  final int id;
  final String name, country, region;
  final bool isActive;
  const TherapistLocationModel({
    required this.id,
    required this.name,
    required this.country,
    this.region = '',
    this.isActive = true,
  });
  String get displayName =>
      [name, region, country].where((part) => part.isNotEmpty).join(', ');
  factory TherapistLocationModel.fromJson(Map<String, dynamic> json) =>
      TherapistLocationModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        country: json['country'] as String,
        region: json['region'] as String? ?? '',
        isActive: json['isActive'] == true,
      );
}
