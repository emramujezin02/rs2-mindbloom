class PaymentIntentResponse {
  final String clientSecret;
  final String paymentIntentId;
  final int appointmentId;
  final double amount;
  final String currency;
  final String purpose;

  const PaymentIntentResponse({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.appointmentId,
    required this.amount,
    required this.currency,
    required this.purpose,
  });

  factory PaymentIntentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentIntentResponse(
      clientSecret: json['clientSecret']?.toString() ?? '',
      paymentIntentId: json['paymentIntentId']?.toString() ?? '',
      appointmentId: _toInt(json['appointmentId']),
      amount: _toDouble(json['amount']),
      currency: json['currency']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
