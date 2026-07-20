class TherapistModel {
  final int id;
  final int userId;
  final String fullName;
  final String email;
  final String specialization;
  final String biography;
  final double hourlyRate;
  final int experienceYears;
  final double averageRating;
  final String? profileImageUrl;

  const TherapistModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.specialization,
    required this.biography,
    required this.hourlyRate,
    required this.experienceYears,
    required this.averageRating,
    this.profileImageUrl,
  });

  factory TherapistModel.fromJson(Map<String, dynamic> json) {
    return TherapistModel(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      specialization: json['specialization'] ?? '',
      biography: json['biography'] ?? '',
      hourlyRate: (json['hourlyRate'] ?? 0).toDouble(),
      experienceYears: json['experienceYears'] ?? 0,
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      profileImageUrl: _nullableString(json['profileImageUrl']),
    );
  }

  static String? _nullableString(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalizedValue = value.trim();

    return normalizedValue.isEmpty ? null : normalizedValue;
  }
}
