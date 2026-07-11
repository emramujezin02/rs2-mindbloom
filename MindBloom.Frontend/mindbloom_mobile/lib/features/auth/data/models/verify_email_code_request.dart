class VerifyEmailCodeRequest {
  final String email;
  final String code;

  VerifyEmailCodeRequest({required this.email, required this.code});

  Map<String, dynamic> toJson() {
    return {'email': email, 'code': code};
  }
}
