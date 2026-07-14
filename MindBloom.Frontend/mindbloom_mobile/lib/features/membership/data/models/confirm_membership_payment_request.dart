class ConfirmMembershipPaymentRequest {
  final String paymentIntentId;

  const ConfirmMembershipPaymentRequest({required this.paymentIntentId});

  Map<String, dynamic> toJson() {
    return {'paymentIntentId': paymentIntentId};
  }
}
