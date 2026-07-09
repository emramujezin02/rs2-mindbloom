class UpdateProfileRequest {
  final String firstName;
  final String lastName;
  final String phoneNumber;

  UpdateProfileRequest({
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
    };
  }
}
