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
  final String country;
  final String city;
  final String address;
  final bool offersOnline;
  final bool offersInPerson;

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
    required this.country,
    required this.city,
    required this.address,
    required this.offersOnline,
    required this.offersInPerson,
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
      country: json['country'] ?? '',
      city: json['city'] ?? '',
      address: json['address'] ?? '',
      offersOnline: json['offersOnline'] == true,
      offersInPerson: json['offersInPerson'] == true,
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

  static String? _nullableString(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalizedValue = value.trim();

    return normalizedValue.isEmpty ? null : normalizedValue;
  }
}
