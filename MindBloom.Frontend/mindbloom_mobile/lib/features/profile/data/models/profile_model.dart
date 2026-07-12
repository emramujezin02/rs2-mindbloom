class ProfileModel {
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final DateTime? dateOfBirth;
  final String? profileImageUrl;

  ProfileModel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    this.dateOfBirth,
    this.profileImageUrl,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final dateOfBirthValue = json['dateOfBirth'];

    return ProfileModel(
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      dateOfBirth: dateOfBirthValue is String && dateOfBirthValue.isNotEmpty
          ? DateTime.tryParse(dateOfBirthValue)
          : null,
      profileImageUrl: json['profileImageUrl'],
    );
  }
}
