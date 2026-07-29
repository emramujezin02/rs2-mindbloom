import '../../../therapy_approach/data/models/therapy_approach_model.dart';
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
  final String country;
  final String city;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool offersOnline;
  final bool offersInPerson;
  final List<String> languages;
  final String? profileImageUrl;
  final String verificationStatus;
  final List<TherapistProfileAvailabilityModel> availabilities;
  final List<TherapyApproachModel> therapyApproaches;

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
    required this.country,
    required this.city,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.offersOnline,
    required this.offersInPerson,
    required this.languages,
    required this.profileImageUrl,
    required this.verificationStatus,
    required this.availabilities,
    required this.therapyApproaches,
  });

  factory TherapistProfileModel.fromJson(Map<String, dynamic> json) {
    final rawLanguages = json['languages'];
    final rawAvailabilities = json['availabilities'];
    final rawTherapyApproaches = json['therapyApproaches'];

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
      country: json['country']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: _readNullableDouble(json['latitude']),
      longitude: _readNullableDouble(json['longitude']),
      offersOnline: _readBool(json['offersOnline']),
      offersInPerson: _readBool(json['offersInPerson']),
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
      therapyApproaches: rawTherapyApproaches is List
          ? rawTherapyApproaches
                .whereType<Map>()
                .map(
                  (item) => TherapyApproachModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where(
                  (approach) => approach.id > 0 && approach.name.isNotEmpty,
                )
                .toList()
          : <TherapyApproachModel>[],
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
    String? country,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
    bool? offersOnline,
    bool? offersInPerson,
    List<String>? languages,
    String? profileImageUrl,
    String? verificationStatus,
    List<TherapistProfileAvailabilityModel>? availabilities,
    List<TherapyApproachModel>? therapyApproaches,
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
      country: country ?? this.country,
      city: city ?? this.city,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      offersOnline: offersOnline ?? this.offersOnline,
      offersInPerson: offersInPerson ?? this.offersInPerson,
      languages: languages ?? this.languages,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      availabilities: availabilities ?? this.availabilities,
      therapyApproaches: therapyApproaches ?? this.therapyApproaches,
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _readNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final normalized = value?.toString().trim().toLowerCase();

    return normalized == 'true' || normalized == '1';
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
          .toSet()
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
    }

    return <String>[];
  }
}
