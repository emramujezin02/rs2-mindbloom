class RegisterRequest {
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String password;
  final String gender;
  final DateTime dateOfBirth;

  final bool acceptPrivacyPolicy;
  final String privacyPolicyVersion;

  final bool acceptTermsOfService;
  final String termsOfServiceVersion;

  RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.password,
    this.gender = 'Other',
    required this.dateOfBirth,
    required this.acceptPrivacyPolicy,
    required this.privacyPolicyVersion,
    required this.acceptTermsOfService,
    required this.termsOfServiceVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'password': password,
      'gender': gender,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'acceptPrivacyPolicy': acceptPrivacyPolicy,
      'privacyPolicyVersion': privacyPolicyVersion,
      'acceptTermsOfService': acceptTermsOfService,
      'termsOfServiceVersion': termsOfServiceVersion,
    };
  }
}
