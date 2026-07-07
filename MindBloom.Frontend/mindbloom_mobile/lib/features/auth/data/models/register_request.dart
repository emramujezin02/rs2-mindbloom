class RegisterRequest {
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String password;
  final DateTime dateOfBirth;

  RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.password,
    required this.dateOfBirth,
  });

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'password': password,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'role': 'Client',
    };
  }
}
