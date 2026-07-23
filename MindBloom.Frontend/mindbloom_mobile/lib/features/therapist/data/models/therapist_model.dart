class TherapistModel {
  final int id;
  final int? userId;
  final String fullName;
  final String email;
  final String specialization;
  final List<String> therapyApproaches;
  final String biography;
  final double hourlyRate;
  final int experienceYears;
  final double averageRating;
  final int totalReviews;
  final String verificationStatus;
  final String? profileImageUrl;

  final String country;
  final String city;
  final String address;
  final bool offersOnline;
  final bool offersInPerson;

  final double? latitude;
  final double? longitude;

  const TherapistModel({
    required this.id,
    this.userId,
    required this.fullName,
    required this.email,
    required this.specialization,
    required this.therapyApproaches,
    required this.biography,
    required this.hourlyRate,
    required this.experienceYears,
    required this.averageRating,
    required this.totalReviews,
    required this.verificationStatus,
    this.profileImageUrl,
    required this.country,
    required this.city,
    required this.address,
    required this.offersOnline,
    required this.offersInPerson,
    this.latitude,
    this.longitude,
  });

  factory TherapistModel.fromJson(Map<String, dynamic> json) {
    return TherapistModel(
      id: _intValue(json['id']),
      userId: _nullableInt(json['userId']),
      fullName: _stringValue(json['fullName']),
      email: _stringValue(json['email']),
      specialization: _stringValue(json['specialization']),
      therapyApproaches: _stringListValue(json['therapyApproaches']),
      biography: _stringValue(json['biography']),
      hourlyRate: _doubleValue(json['hourlyRate']),
      experienceYears: _intValue(json['experienceYears']),
      averageRating: _doubleValue(json['averageRating']),
      totalReviews: _intValue(json['totalReviews']),
      verificationStatus: _stringValue(json['verificationStatus']),
      profileImageUrl: _nullableString(json['profileImageUrl']),
      country: _stringValue(json['country']),
      city: _stringValue(json['city']),
      address: _stringValue(json['address']),
      offersOnline: _boolValue(json['offersOnline']),
      offersInPerson: _boolValue(json['offersInPerson']),
      latitude: _nullableDouble(json['latitude']),
      longitude: _nullableDouble(json['longitude']),
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

  static int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
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

    if (value is double) {
      return value;
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

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    if (value is num) {
      return value != 0;
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

    final result = value.toString().trim();

    return result.isEmpty ? null : result;
  }

  static List<String> _stringListValue(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  bool get isVerified {
    return verificationStatus.toLowerCase() == 'approved';
  }
}
