import 'auth_response.dart';

class Login2FAResponse {
  final bool requiresTwoFactor;
  final String message;
  final AuthResponse? auth;

  Login2FAResponse({
    required this.requiresTwoFactor,
    required this.message,
    this.auth,
  });

  factory Login2FAResponse.fromJson(Map<String, dynamic> json) {
    final authJson = json['auth'];

    return Login2FAResponse(
      requiresTwoFactor: json['requiresTwoFactor'] ?? false,
      message: json['message'] ?? '',
      auth: authJson is Map<String, dynamic>
          ? AuthResponse.fromJson(authJson)
          : null,
    );
  }
}
