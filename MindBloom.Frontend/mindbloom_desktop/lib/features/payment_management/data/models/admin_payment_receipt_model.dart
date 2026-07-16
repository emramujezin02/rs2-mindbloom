class AdminPaymentReceiptModel {
  final String invoiceNumber;
  final int paymentId;
  final int appointmentId;
  final String clientName;
  final String clientEmail;
  final String therapistName;
  final double amount;
  final String currency;
  final String status;
  final DateTime paymentDateUtc;
  final DateTime appointmentStartUtc;
  final DateTime appointmentEndUtc;
  final String stripePaymentIntentId;
  final String? stripeRefundId;
  final String? refundReason;
  final DateTime? refundedAtUtc;

  const AdminPaymentReceiptModel({
    required this.invoiceNumber,
    required this.paymentId,
    required this.appointmentId,
    required this.clientName,
    required this.clientEmail,
    required this.therapistName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentDateUtc,
    required this.appointmentStartUtc,
    required this.appointmentEndUtc,
    required this.stripePaymentIntentId,
    required this.stripeRefundId,
    required this.refundReason,
    required this.refundedAtUtc,
  });

  factory AdminPaymentReceiptModel.fromJson(Map<String, dynamic> json) {
    return AdminPaymentReceiptModel(
      invoiceNumber: json['invoiceNumber'] ?? '',
      paymentId: json['paymentId'] ?? 0,
      appointmentId: json['appointmentId'] ?? 0,
      clientName: json['clientName'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      therapistName: json['therapistName'] ?? '',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? '',
      paymentDateUtc: DateTime.parse(json['paymentDateUtc']),
      appointmentStartUtc: DateTime.parse(json['appointmentStartUtc']),
      appointmentEndUtc: DateTime.parse(json['appointmentEndUtc']),
      stripePaymentIntentId: json['stripePaymentIntentId'] ?? '',
      stripeRefundId: json['stripeRefundId'],
      refundReason: json['refundReason'],
      refundedAtUtc: json['refundedAtUtc'] == null
          ? null
          : DateTime.parse(json['refundedAtUtc']),
    );
  }
}
