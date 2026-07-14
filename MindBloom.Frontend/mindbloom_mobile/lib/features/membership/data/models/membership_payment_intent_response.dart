class MembershipPaymentIntentResponse {
  final int membershipId;
  final String clientSecret;
  final String paymentIntentId;
  final double amount;
  final String currency;

  const MembershipPaymentIntentResponse({
    required this.membershipId,
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amount,
    required this.currency,
  });

  factory MembershipPaymentIntentResponse.fromJson(Map<String, dynamic> json) {
    return MembershipPaymentIntentResponse(
      membershipId: json['membershipId'] ?? 0,

      clientSecret: json['clientSecret'] ?? '',

      paymentIntentId: json['paymentIntentId'] ?? '',

      amount: (json['amount'] as num?)?.toDouble() ?? 0,

      currency: json['currency'] ?? '',
    );
  }
}
