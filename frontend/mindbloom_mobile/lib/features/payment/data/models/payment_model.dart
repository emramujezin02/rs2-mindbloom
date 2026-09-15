class PaymentModel {
  final int id;
  final String paymentType;
  final int? appointmentId;
  final int? membershipId;
  final String therapistName;
  final String purpose;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAtUtc;
  final DateTime? paidAtUtc;
  final String? refundReason;
  final DateTime? refundRequestedAtUtc;
  final DateTime? refundedAtUtc;
  final String? refundFailureReason;

  const PaymentModel({
    required this.id,
    required this.paymentType,
    required this.appointmentId,
    required this.membershipId,
    required this.therapistName,
    required this.purpose,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAtUtc,
    required this.paidAtUtc,
    required this.refundReason,
    required this.refundRequestedAtUtc,
    required this.refundedAtUtc,
    required this.refundFailureReason,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: _toInt(json['id']),
      paymentType: json['paymentType']?.toString() ?? '',
      appointmentId: _toNullableInt(json['appointmentId']),
      membershipId: _toNullableInt(json['membershipId']),
      therapistName: json['therapistName']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      currency: json['currency']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAtUtc: _toDateTime(json['createdAtUtc']),
      paidAtUtc: _toNullableDateTime(json['paidAtUtc']),
      refundReason: _toNullableString(json['refundReason']),
      refundRequestedAtUtc: _toNullableDateTime(json['refundRequestedAtUtc']),
      refundedAtUtc: _toNullableDateTime(json['refundedAtUtc']),
      refundFailureReason: _toNullableString(json['refundFailureReason']),
    );
  }

  String get normalizedStatus {
    return status.trim().toLowerCase();
  }

  String get normalizedPaymentType {
    return paymentType.trim().toLowerCase();
  }

  bool get isAppointmentPayment {
    return normalizedPaymentType == 'appointment';
  }

  bool get isMembershipPayment {
    return normalizedPaymentType == 'membership';
  }

  bool get isPending => normalizedStatus == 'pending';

  bool get isPaid => normalizedStatus == 'paid';

  bool get isFailed => normalizedStatus == 'failed';

  bool get isRefundPending => normalizedStatus == 'refundpending';

  bool get isRefunded => normalizedStatus == 'refunded';

  bool get isRefundFailed => normalizedStatus == 'refundfailed';

  bool get hasRefundProcess {
    return isRefundPending || isRefunded || isRefundFailed;
  }

  String get displayStatus {
    if (isPending) {
      return 'Pending';
    }

    if (isPaid) {
      return 'Paid';
    }

    if (isFailed) {
      return 'Failed';
    }

    if (isRefundPending) {
      return 'Refund pending';
    }

    if (isRefunded) {
      return 'Refunded';
    }

    if (isRefundFailed) {
      return 'Refund failed';
    }

    return status;
  }

  String get displayType {
    if (isAppointmentPayment) {
      return 'Appointment payment';
    }

    if (isMembershipPayment) {
      return 'Membership payment';
    }

    return paymentType;
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

    final parsed = _toInt(value);

    return parsed > 0 ? parsed : null;
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
