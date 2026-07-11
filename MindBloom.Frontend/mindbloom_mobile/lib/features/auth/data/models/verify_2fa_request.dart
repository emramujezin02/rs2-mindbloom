class Verify2FARequest {
  final String email;
  final String code;

  Verify2FARequest({required this.email, required this.code});

  Map<String, dynamic> toJson() {
    return {'email': email, 'code': code};
  }
}
