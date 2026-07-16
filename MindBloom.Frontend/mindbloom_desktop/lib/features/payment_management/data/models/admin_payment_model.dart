class AdminPaymentModel {
  final int id;
  final int appointmentId;
  final String clientName;
  final String clientEmail;
  final String therapistName;
  final double amount;
  final String currency;
  final String status;
  final String appointmentStatus;
  final DateTime createdAtUtc;
  final DateTime? paidAtUtc;
  final DateTime? refundedAtUtc;
  final bool canRefund;

  const AdminPaymentModel({
    required this.id,
    required this.appointmentId,
    required this.clientName,
    required this.clientEmail,
    required this.therapistName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.appointmentStatus,
    required this.createdAtUtc,
    required this.paidAtUtc,
    required this.refundedAtUtc,
    required this.canRefund,
  });

  factory AdminPaymentModel.fromJson(Map<String, dynamic> json) {
    return AdminPaymentModel(
      id: json['id'] ?? 0,
      appointmentId: json['appointmentId'] ?? 0,
      clientName: json['clientName'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      therapistName: json['therapistName'] ?? '',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? '',
      appointmentStatus: json['appointmentStatus'] ?? '',
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
      paidAtUtc: json['paidAtUtc'] == null
          ? null
          : DateTime.parse(json['paidAtUtc']),
      refundedAtUtc: json['refundedAtUtc'] == null
          ? null
          : DateTime.parse(json['refundedAtUtc']),
      canRefund: json['canRefund'] ?? false,
    );
  }
}
