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
    required this.hourlyRate,
    required this.experienceYears,
    required this.averageRating,
    required this.totalReviews,
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
      hourlyRate: _doubleValue(json['hourlyRate']),
      experienceYears: _intValue(json['experienceYears']),
      averageRating: _doubleValue(json['averageRating']),
      totalReviews: _intValue(json['totalReviews']),
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
                .whereType<Map<String, dynamic>>()
                .map(TherapistAvailabilityModel.fromJson)
                .toList()
          : <TherapistAvailabilityModel>[],
    );
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
      biography: biography,
      hourlyRate: hourlyRate,
      experienceYears: experienceYears,
      averageRating: averageRating,
      totalReviews: totalReviews,
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
}
