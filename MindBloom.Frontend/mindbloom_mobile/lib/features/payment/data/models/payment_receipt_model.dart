class PaymentReceiptModel {
  final int paymentId;
  final int appointmentId;
  final String therapistName;
  final String clientName;
  final double amount;
  final String currency;
  final String purpose;
  final String status;
  final DateTime paymentDateUtc;
  final DateTime appointmentStartUtc;
  final DateTime appointmentEndUtc;
  final String invoiceNumber;
  final String stripePaymentIntentId;
  final String? stripeRefundId;
  final String? refundReason;
  final DateTime? refundRequestedAtUtc;
  final DateTime? refundedAtUtc;
  final String? refundFailureReason;

  const PaymentReceiptModel({
    required this.paymentId,
    required this.appointmentId,
    required this.therapistName,
    required this.clientName,
    required this.amount,
    required this.currency,
    required this.purpose,
    required this.status,
    required this.paymentDateUtc,
    required this.appointmentStartUtc,
    required this.appointmentEndUtc,
    required this.invoiceNumber,
    required this.stripePaymentIntentId,
    required this.stripeRefundId,
    required this.refundReason,
    required this.refundRequestedAtUtc,
    required this.refundedAtUtc,
    required this.refundFailureReason,
  });

  factory PaymentReceiptModel.fromJson(Map<String, dynamic> json) {
    return PaymentReceiptModel(
      paymentId: _toInt(json['paymentId']),
      appointmentId: _toInt(json['appointmentId']),
      therapistName: json['therapistName']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      currency: json['currency']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      paymentDateUtc: _toDateTime(json['paymentDateUtc']),
      appointmentStartUtc: _toDateTime(json['appointmentStartUtc']),
      appointmentEndUtc: _toDateTime(json['appointmentEndUtc']),
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      stripePaymentIntentId: json['stripePaymentIntentId']?.toString() ?? '',
      stripeRefundId: _toNullableString(json['stripeRefundId']),
      refundReason: _toNullableString(json['refundReason']),
      refundRequestedAtUtc: _toNullableDateTime(json['refundRequestedAtUtc']),
      refundedAtUtc: _toNullableDateTime(json['refundedAtUtc']),
      refundFailureReason: _toNullableString(json['refundFailureReason']),
    );
  }

  bool get hasRefundInformation {
    return stripeRefundId != null ||
        refundReason != null ||
        refundRequestedAtUtc != null ||
        refundedAtUtc != null ||
        refundFailureReason != null;
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

  static DateTime _toDateTime(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  static String? _toNullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? null : text;
  }
}
