class ProfileModel {
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final DateTime? dateOfBirth;
  final String? profileImageUrl;

  final String? location;
  final String? preferredTherapistGender;
  final String? preferredSessionType;
  final double? minimumPricePerSession;
  final double? maximumPricePerSession;
  final List<String> preferredLanguages;

  const ProfileModel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    this.dateOfBirth,
    this.profileImageUrl,
    this.location,
    this.preferredTherapistGender,
    this.preferredSessionType,
    this.minimumPricePerSession,
    this.maximumPricePerSession,
    this.preferredLanguages = const [],
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final dateOfBirthValue = json['dateOfBirth'];

    final languagesValue = json['preferredLanguages'];

    return ProfileModel(
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      dateOfBirth: dateOfBirthValue is String && dateOfBirthValue.isNotEmpty
          ? DateTime.tryParse(dateOfBirthValue)
          : null,
      profileImageUrl: _nullableString(json['profileImageUrl']),
      location: _nullableString(json['location']),
      preferredTherapistGender: _nullableString(
        json['preferredTherapistGender'],
      ),
      preferredSessionType: _nullableString(json['preferredSessionType']),
      minimumPricePerSession: _nullableDouble(json['minimumPricePerSession']),
      maximumPricePerSession: _nullableDouble(json['maximumPricePerSession']),
      preferredLanguages: languagesValue is List
          ? languagesValue
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : const [],
    );
  }

  static String? _nullableString(dynamic value) {
    final normalized = value?.toString().trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
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
}
