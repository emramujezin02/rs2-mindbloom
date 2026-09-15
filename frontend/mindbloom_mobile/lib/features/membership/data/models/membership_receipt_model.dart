class MembershipReceiptModel {
  final int membershipId;
  final int paymentId;
  final String invoiceNumber;
  final String clientName;
  final String therapistName;
  final String planType;
  final int totalSessions;
  final double amount;
  final String currency;
  final String paymentStatus;
  final DateTime paidAtUtc;
  final DateTime? expiresAtUtc;

  const MembershipReceiptModel({
    required this.membershipId,
    required this.paymentId,
    required this.invoiceNumber,
    required this.clientName,
    required this.therapistName,
    required this.planType,
    required this.totalSessions,
    required this.amount,
    required this.currency,
    required this.paymentStatus,
    required this.paidAtUtc,
    this.expiresAtUtc,
  });

  factory MembershipReceiptModel.fromJson(Map<String, dynamic> json) {
    final paidAtValue = json['paidAtUtc'];

    final expiresAtValue = json['expiresAtUtc'];

    return MembershipReceiptModel(
      membershipId: json['membershipId'] ?? 0,

      paymentId: json['paymentId'] ?? 0,

      invoiceNumber: json['invoiceNumber'] ?? '',

      clientName: json['clientName'] ?? '',

      therapistName: json['therapistName'] ?? '',

      planType: json['planType'] ?? '',

      totalSessions: json['totalSessions'] ?? 0,

      amount: (json['amount'] as num?)?.toDouble() ?? 0,

      currency: json['currency'] ?? '',

      paymentStatus: json['paymentStatus'] ?? '',

      paidAtUtc: paidAtValue is String
          ? DateTime.parse(paidAtValue)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),

      expiresAtUtc: expiresAtValue is String && expiresAtValue.isNotEmpty
          ? DateTime.tryParse(expiresAtValue)
          : null,
    );
  }
}
