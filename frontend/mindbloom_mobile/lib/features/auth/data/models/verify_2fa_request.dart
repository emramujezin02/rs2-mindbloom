class Verify2FARequest {
  final String challengeToken;

  final String code;

  const Verify2FARequest({required this.challengeToken, required this.code});

  Map<String, dynamic> toJson() {
    return {'challengeToken': challengeToken, 'code': code};
  }
}
