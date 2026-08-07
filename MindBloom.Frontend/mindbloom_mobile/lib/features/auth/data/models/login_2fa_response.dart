import 'auth_response.dart';

class Login2FAResponse {
  final bool requiresTwoFactor;
  final String message;

  final String? challengeToken;

  final DateTime? challengeExpiresAtUtc;

  final AuthResponse? auth;

  const Login2FAResponse({
    required this.requiresTwoFactor,
    required this.message,
    this.challengeToken,
    this.challengeExpiresAtUtc,
    this.auth,
  });

  factory Login2FAResponse.fromJson(Map<String, dynamic> json) {
    final authJson = json['auth'];

    final expiresAtValue = json['challengeExpiresAtUtc'];

    return Login2FAResponse(
      requiresTwoFactor: json['requiresTwoFactor'] == true,

      message: json['message']?.toString() ?? '',

      challengeToken: json['challengeToken']?.toString(),

      challengeExpiresAtUtc: expiresAtValue == null
          ? null
          : DateTime.tryParse(expiresAtValue.toString()),

      auth: authJson is Map<String, dynamic>
          ? AuthResponse.fromJson(authJson)
          : null,
    );
  }
}
