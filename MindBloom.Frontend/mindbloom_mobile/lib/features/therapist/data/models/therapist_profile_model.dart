import 'therapist_profile_availability_model.dart';

class TherapistProfileModel {
  final int therapistId;
  final int userId;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String biography;
  final String specialization;
  final int experienceYears;
  final double hourlyRate;
  final String location;
  final List<String> languages;
  final String? profileImageUrl;
  final String verificationStatus;
  final List<TherapistProfileAvailabilityModel> availabilities;

  const TherapistProfileModel({
    required this.therapistId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.biography,
    required this.specialization,
    required this.experienceYears,
    required this.hourlyRate,
    required this.location,
    required this.languages,
    required this.profileImageUrl,
    required this.verificationStatus,
    required this.availabilities,
  });

  factory TherapistProfileModel.fromJson(Map<String, dynamic> json) {
    final rawLanguages = json['languages'];
    final rawAvailabilities = json['availabilities'];

    return TherapistProfileModel(
      therapistId: _readInt(json['therapistId']),
      userId: _readInt(json['userId']),
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: _readNullableString(json['phoneNumber']),
      biography: json['biography']?.toString() ?? '',
      specialization: json['specialization']?.toString() ?? '',
      experienceYears: _readInt(json['experienceYears']),
      hourlyRate: _readDouble(json['hourlyRate']),
      location: json['location']?.toString() ?? '',
      languages: _readLanguages(rawLanguages),
      profileImageUrl: _readNullableString(json['profileImageUrl']),
      verificationStatus: json['verificationStatus']?.toString() ?? '',
      availabilities: rawAvailabilities is List
          ? rawAvailabilities
                .whereType<Map>()
                .map(
                  (item) => TherapistProfileAvailabilityModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : <TherapistProfileAvailabilityModel>[],
    );
  }

  TherapistProfileModel copyWith({
    int? therapistId,
    int? userId,
    String? firstName,
    String? lastName,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? biography,
    String? specialization,
    int? experienceYears,
    double? hourlyRate,
    String? location,
    List<String>? languages,
    String? profileImageUrl,
    String? verificationStatus,
    List<TherapistProfileAvailabilityModel>? availabilities,
  }) {
    return TherapistProfileModel(
      therapistId: therapistId ?? this.therapistId,
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      biography: biography ?? this.biography,
      specialization: specialization ?? this.specialization,
      experienceYears: experienceYears ?? this.experienceYears,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      location: location ?? this.location,
      languages: languages ?? this.languages,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      availabilities: availabilities ?? this.availabilities,
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _readNullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static List<String> _readLanguages(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return <String>[];
  }
}
