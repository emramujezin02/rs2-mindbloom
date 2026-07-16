class AdminPaymentDetailsModel {
  final int id;
  final int appointmentId;
  final int clientId;
  final int clientUserId;
  final String clientName;
  final String clientEmail;
  final int therapistId;
  final String therapistName;
  final String therapistEmail;
  final double amount;
  final String currency;
  final String status;
  final String appointmentStatus;
  final DateTime appointmentStartUtc;
  final DateTime appointmentEndUtc;
  final String appointmentType;
  final String stripePaymentIntentId;
  final DateTime createdAtUtc;
  final DateTime? paidAtUtc;
  final String? stripeRefundId;
  final String? refundReason;
  final DateTime? refundRequestedAtUtc;
  final DateTime? refundedAtUtc;
  final String? refundFailureReason;
  final bool appointmentIsPaid;
  final bool canRefund;

  const AdminPaymentDetailsModel({
    required this.id,
    required this.appointmentId,
    required this.clientId,
    required this.clientUserId,
    required this.clientName,
    required this.clientEmail,
    required this.therapistId,
    required this.therapistName,
    required this.therapistEmail,
    required this.amount,
    required this.currency,
    required this.status,
    required this.appointmentStatus,
    required this.appointmentStartUtc,
    required this.appointmentEndUtc,
    required this.appointmentType,
    required this.stripePaymentIntentId,
    required this.createdAtUtc,
    required this.paidAtUtc,
    required this.stripeRefundId,
    required this.refundReason,
    required this.refundRequestedAtUtc,
    required this.refundedAtUtc,
    required this.refundFailureReason,
    required this.appointmentIsPaid,
    required this.canRefund,
  });

  factory AdminPaymentDetailsModel.fromJson(Map<String, dynamic> json) {
    return AdminPaymentDetailsModel(
      id: json['id'] ?? 0,
      appointmentId: json['appointmentId'] ?? 0,
      clientId: json['clientId'] ?? 0,
      clientUserId: json['clientUserId'] ?? 0,
      clientName: json['clientName'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      therapistId: json['therapistId'] ?? 0,
      therapistName: json['therapistName'] ?? '',
      therapistEmail: json['therapistEmail'] ?? '',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? '',
      appointmentStatus: json['appointmentStatus'] ?? '',
      appointmentStartUtc: DateTime.parse(json['appointmentStartUtc']),
      appointmentEndUtc: DateTime.parse(json['appointmentEndUtc']),
      appointmentType: json['appointmentType'] ?? '',
      stripePaymentIntentId: json['stripePaymentIntentId'] ?? '',
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
      paidAtUtc: json['paidAtUtc'] == null
          ? null
          : DateTime.parse(json['paidAtUtc']),
      stripeRefundId: json['stripeRefundId'],
      refundReason: json['refundReason'],
      refundRequestedAtUtc: json['refundRequestedAtUtc'] == null
          ? null
          : DateTime.parse(json['refundRequestedAtUtc']),
      refundedAtUtc: json['refundedAtUtc'] == null
          ? null
          : DateTime.parse(json['refundedAtUtc']),
      refundFailureReason: json['refundFailureReason'],
      appointmentIsPaid: json['appointmentIsPaid'] ?? false,
      canRefund: json['canRefund'] ?? false,
    );
  }
}
