class UpdateProfileRequest {
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final DateTime dateOfBirth;
  final String? location;
  final String? preferredTherapistGender;
  final String? preferredSessionType;
  final double? minimumPricePerSession;
  final double? maximumPricePerSession;
  final List<String> preferredLanguages;

  const UpdateProfileRequest({
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.dateOfBirth,
    this.location,
    this.preferredTherapistGender,
    this.preferredSessionType,
    this.minimumPricePerSession,
    this.maximumPricePerSession,
    this.preferredLanguages = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'phoneNumber': _nullableText(phoneNumber),
      'dateOfBirth': DateTime(
        dateOfBirth.year,
        dateOfBirth.month,
        dateOfBirth.day,
      ).toIso8601String(),
      'location': _nullableText(location),
      'preferredTherapistGender': _nullableText(preferredTherapistGender),
      'preferredSessionType': _nullableText(preferredSessionType),
      'minimumPricePerSession': minimumPricePerSession,
      'maximumPricePerSession': maximumPricePerSession,
      'preferredLanguages': preferredLanguages,
    };
  }

  static String? _nullableText(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
