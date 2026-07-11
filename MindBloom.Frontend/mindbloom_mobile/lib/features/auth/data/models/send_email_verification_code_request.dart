class SendEmailVerificationCodeRequest {
  final String email;

  SendEmailVerificationCodeRequest({required this.email});

  Map<String, dynamic> toJson() {
    return {'email': email};
  }
}
