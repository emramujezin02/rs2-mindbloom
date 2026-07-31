class AdminPaymentModel {
  final int id;
  final String paymentType;
  final int? appointmentId;
  final int? membershipId;
  final String clientName;
  final String clientEmail;
  final String therapistName;
  final double amount;
  final String currency;
  final String status;
  final String purpose;
  final DateTime createdAtUtc;
  final DateTime? paidAtUtc;
  final DateTime? refundedAtUtc;
  final bool canRefund;
  final String? refundUnavailableReason;

  const AdminPaymentModel({
    required this.id,
    required this.paymentType,
    required this.appointmentId,
    required this.membershipId,
    required this.clientName,
    required this.clientEmail,
    required this.therapistName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.purpose,
    required this.createdAtUtc,
    required this.paidAtUtc,
    required this.refundedAtUtc,
    required this.canRefund,
    required this.refundUnavailableReason,
  });

  factory AdminPaymentModel.fromJson(Map<String, dynamic> json) {
    return AdminPaymentModel(
      id: _toInt(json['id']),
      paymentType: json['paymentType']?.toString() ?? '',
      appointmentId: _toNullableInt(json['appointmentId']),
      membershipId: _toNullableInt(json['membershipId']),
      clientName: json['clientName']?.toString() ?? '',
      clientEmail: json['clientEmail']?.toString() ?? '',
      therapistName: json['therapistName']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      currency: json['currency']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      paidAtUtc: _toNullableDateTime(json['paidAtUtc']),
      refundedAtUtc: _toNullableDateTime(json['refundedAtUtc']),
      canRefund: json['canRefund'] == true,
      refundUnavailableReason: json['refundUnavailableReason']?.toString(),
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

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
