import 'therapist_availability_model.dart';
import 'therapist_model.dart';

class TherapistDetailsModel {
  final int id;
  final String fullName;
  final String email;
  final String biography;
  final String specialization;
  final List<String> therapyApproaches;
  final List<String> languages;
  final double hourlyRate;
  final int experienceYears;
  final double averageRating;
  final int totalReviews;
  final String verificationStatus;
  final bool canChat;
  final int? chatAppointmentId;
  final String? profileImageUrl;

  final String country;
  final String city;
  final String address;
  final bool offersOnline;
  final bool offersInPerson;

  final double? latitude;
  final double? longitude;

  final List<TherapistAvailabilityModel> availabilities;

  const TherapistDetailsModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.biography,
    required this.specialization,
    required this.therapyApproaches,
    required this.languages,
    required this.hourlyRate,
    required this.experienceYears,
    required this.averageRating,
    required this.totalReviews,
    required this.verificationStatus,
    required this.canChat,
    this.chatAppointmentId,
    required this.country,
    required this.city,
    required this.address,
    required this.offersOnline,
    required this.offersInPerson,
    required this.availabilities,
    this.profileImageUrl,
    this.latitude,
    this.longitude,
  });

  factory TherapistDetailsModel.fromJson(Map<String, dynamic> json) {
    final availabilityJson = json['availabilities'];

    return TherapistDetailsModel(
      id: _intValue(json['id']),
      fullName: _stringValue(json['fullName']),
      email: _stringValue(json['email']),
      biography: _stringValue(json['biography']),
      specialization: _stringValue(json['specialization']),
      therapyApproaches: _stringListValue(json['therapyApproaches']),
      languages: _stringListValue(json['languages']),
      hourlyRate: _doubleValue(json['hourlyRate']),
      experienceYears: _intValue(json['experienceYears']),
      averageRating: _doubleValue(json['averageRating']),
      totalReviews: _intValue(json['totalReviews']),
      verificationStatus: _stringValue(json['verificationStatus']),
      canChat: _boolValue(json['canChat']),
      chatAppointmentId: _nullableInt(json['chatAppointmentId']),
      profileImageUrl: _nullableString(json['profileImageUrl']),
      country: _stringValue(json['country']),
      city: _stringValue(json['city']),
      address: _stringValue(json['address']),
      offersOnline: _boolValue(json['offersOnline']),
      offersInPerson: _boolValue(json['offersInPerson']),
      latitude: _nullableDouble(json['latitude']),
      longitude: _nullableDouble(json['longitude']),
      availabilities: availabilityJson is List
          ? availabilityJson
                .whereType<Map>()
                .map(
                  (item) => TherapistAvailabilityModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : <TherapistAvailabilityModel>[],
    );
  }

  String get displayName {
    final value = fullName.trim();
    return value.isEmpty ? 'Therapist' : value;
  }

  String get displayBiography {
    final value = biography.trim();
    return value.isEmpty ? 'No biography added.' : value;
  }

  String get displaySpecialization {
    final value = specialization.trim();
    return value.isEmpty ? 'Not specified' : value;
  }

  String get displayExperience {
    if (experienceYears <= 0) {
      return 'Not specified';
    }

    return '$experienceYears ${experienceYears == 1 ? 'year' : 'years'}';
  }

  String get displayPrice {
    if (hourlyRate <= 0) {
      return 'Not specified';
    }

    return '${hourlyRate.toStringAsFixed(2)} KM';
  }

  String get displayRating {
    if (totalReviews <= 0) {
      return 'No reviews yet';
    }

    return '${averageRating.toStringAsFixed(1)} '
        '($totalReviews ${totalReviews == 1 ? 'review' : 'reviews'})';
  }

  String get displayVerificationStatus {
    final value = verificationStatus.trim();

    if (value.isEmpty) {
      return 'Not specified';
    }

    if (value.toLowerCase() == 'approved') {
      return 'Verified';
    }

    return value;
  }

  String get formattedLocation {
    final locationParts = <String>[
      city.trim(),
      country.trim(),
    ].where((part) => part.isNotEmpty).toList();

    if (locationParts.isEmpty) {
      return 'Location not specified';
    }

    return locationParts.join(', ');
  }

  String get formattedAddress {
    final parts = <String>[
      address.trim(),
      city.trim(),
      country.trim(),
    ].where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty) {
      return 'Address not specified';
    }

    return parts.join(', ');
  }

  String get sessionModeLabel {
    if (offersOnline && offersInPerson) {
      return 'Online and in person';
    }

    if (offersOnline) {
      return 'Online';
    }

    if (offersInPerson) {
      return 'In person';
    }

    return 'Not specified';
  }

  bool get canOpenChat {
    return canChat && chatAppointmentId != null && chatAppointmentId! > 0;
  }

  bool get hasValidCoordinates {
    final currentLatitude = latitude;
    final currentLongitude = longitude;

    if (currentLatitude == null || currentLongitude == null) {
      return false;
    }

    return currentLatitude >= -90 &&
        currentLatitude <= 90 &&
        currentLongitude >= -180 &&
        currentLongitude <= 180 &&
        (currentLatitude != 0 || currentLongitude != 0);
  }

  TherapistModel toTherapistModel() {
    return TherapistModel(
      id: id,
      userId: null,
      fullName: fullName,
      email: email,
      specialization: specialization,
      therapyApproaches: therapyApproaches,
      biography: biography,
      hourlyRate: hourlyRate,
      experienceYears: experienceYears,
      averageRating: averageRating,
      totalReviews: totalReviews,
      verificationStatus: verificationStatus,
      profileImageUrl: profileImageUrl,
      country: country,
      city: city,
      address: address,
      offersOnline: offersOnline,
      offersInPerson: offersInPerson,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleValue(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalizedValue = value.trim().toLowerCase();

      return normalizedValue == 'true' || normalizedValue == '1';
    }

    return false;
  }

  static String _stringValue(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final normalizedValue = value.toString().trim();

    return normalizedValue.isEmpty ? null : normalizedValue;
  }

  static List<String> _stringListValue(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }
}
