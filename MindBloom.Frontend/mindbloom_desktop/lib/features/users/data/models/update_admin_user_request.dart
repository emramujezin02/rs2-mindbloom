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
    return {
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'gender': gender,
    };
  }
}
