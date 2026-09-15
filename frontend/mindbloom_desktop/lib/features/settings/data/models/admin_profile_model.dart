class AdminProfileModel {
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final DateTime dateOfBirth;
  final String? profileImageUrl;

  const AdminProfileModel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.profileImageUrl,
  });

  factory AdminProfileModel.fromJson(Map<String, dynamic> json) {
    return AdminProfileModel(
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      dateOfBirth:
          DateTime.tryParse(json['dateOfBirth']?.toString() ?? '') ??
          DateTime(2000, 1, 1),
      profileImageUrl: json['profileImageUrl']?.toString(),
    );
  }

  String get fullName {
    final value = '$firstName $lastName'.trim();

    return value.isEmpty ? email : value;
  }
}
