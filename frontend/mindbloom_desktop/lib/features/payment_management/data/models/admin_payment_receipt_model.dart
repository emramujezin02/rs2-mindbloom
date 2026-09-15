class AdminPaymentReceiptModel {
  final String invoiceNumber;
  final int paymentId;
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
  final DateTime paymentDateUtc;
  final DateTime? appointmentStartUtc;
  final DateTime? appointmentEndUtc;
  final String stripePaymentIntentId;
  final String? stripeRefundId;
  final String? refundReason;
  final DateTime? refundedAtUtc;

  const AdminPaymentReceiptModel({
    required this.invoiceNumber,
    required this.paymentId,
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
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      paymentId: _toInt(json['paymentId']),
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
      paymentDateUtc: _toRequiredDateTime(json['paymentDateUtc']),
      appointmentStartUtc: _toNullableDateTime(json['appointmentStartUtc']),
      appointmentEndUtc: _toNullableDateTime(json['appointmentEndUtc']),
      stripePaymentIntentId: json['stripePaymentIntentId']?.toString() ?? '',
      stripeRefundId: json['stripeRefundId']?.toString(),
      refundReason: json['refundReason']?.toString(),
      refundedAtUtc: _toNullableDateTime(json['refundedAtUtc']),
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

  static DateTime _toRequiredDateTime(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
