class UpdateAdminUserRequest {
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final DateTime dateOfBirth;
  final String? gender;

  const UpdateAdminUserRequest({
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    required this.dateOfBirth,
    this.gender,
  });

  Map<String, dynamic> toJson() {
    final normalizedPhone = phoneNumber?.trim();

    final normalizedGender = gender?.trim();

    return {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'phoneNumber': normalizedPhone == null || normalizedPhone.isEmpty
          ? null
          : normalizedPhone,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'gender': normalizedGender == null || normalizedGender.isEmpty
          ? null
          : normalizedGender,
    };
  }
}
