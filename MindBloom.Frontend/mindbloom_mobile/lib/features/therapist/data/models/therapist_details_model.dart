import 'therapist_availability_model.dart';
import 'therapist_model.dart';

class TherapistDetailsModel {
  final int id;
  final String fullName;
  final String email;
  final String biography;
  final String specialization;
  final double hourlyRate;
  final int experienceYears;
  final double averageRating;
  final int totalReviews;
  final String? profileImageUrl;
  final List<TherapistAvailabilityModel> availabilities;

  const TherapistDetailsModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.biography,
    required this.specialization,
    required this.hourlyRate,
    required this.experienceYears,
    required this.averageRating,
    required this.totalReviews,
    required this.availabilities,
    this.profileImageUrl,
  });

  factory TherapistDetailsModel.fromJson(Map<String, dynamic> json) {
    final availabilityJson = json['availabilities'];

    return TherapistDetailsModel(
      id: json['id'] ?? 0,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      biography: json['biography'] ?? '',
      specialization: json['specialization'] ?? '',
      hourlyRate: (json['hourlyRate'] ?? 0).toDouble(),
      experienceYears: json['experienceYears'] ?? 0,
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      totalReviews: json['totalReviews'] ?? 0,
      profileImageUrl: _nullableString(json['profileImageUrl']),
      availabilities: availabilityJson is List
          ? availabilityJson
                .whereType<Map<String, dynamic>>()
                .map(TherapistAvailabilityModel.fromJson)
                .toList()
          : [],
    );
  }

  TherapistModel toTherapistModel() {
    return TherapistModel(
      id: id,
      userId: 0,
      fullName: fullName,
      email: email,
      specialization: specialization,
      biography: biography,
      hourlyRate: hourlyRate,
      experienceYears: experienceYears,
      averageRating: averageRating,
      profileImageUrl: profileImageUrl,
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
