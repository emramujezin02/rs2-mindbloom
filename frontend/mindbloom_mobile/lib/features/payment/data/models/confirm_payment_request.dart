class ConfirmPaymentRequest {
  final String paymentIntentId;

  const ConfirmPaymentRequest({required this.paymentIntentId});

  Map<String, dynamic> toJson() {
    return {'paymentIntentId': paymentIntentId};
  }
}
