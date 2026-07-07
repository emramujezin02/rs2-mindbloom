class AuthResponse {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String token;
  final String refreshToken;
  final String role;

  AuthResponse({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.token,
    required this.refreshToken,
    required this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      id: json['id'] ?? 0,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      token: json['token'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      role: json['role'] ?? '',
    );
  }
}
