class AdminPaymentDetailsModel {
  final int id;
  final String paymentType;
  final int? appointmentId;
  final int? membershipId;

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
  final String purpose;
  final String stripePaymentIntentId;

  final DateTime createdAtUtc;
  final DateTime? paidAtUtc;

  final String? stripeRefundId;
  final String? refundReason;
  final DateTime? refundRequestedAtUtc;
  final DateTime? refundedAtUtc;
  final String? refundFailureReason;

  final String? appointmentStatus;
  final DateTime? appointmentStartUtc;
  final DateTime? appointmentEndUtc;
  final String? appointmentType;
  final bool? appointmentIsPaid;

  final String? membershipPlanType;
  final int? totalSessions;
  final int? remainingSessions;
  final bool? membershipIsActive;
  final DateTime? membershipExpiresAtUtc;

  final bool canRefund;
  final String? refundUnavailableReason;

  const AdminPaymentDetailsModel({
    required this.id,
    required this.paymentType,
    required this.appointmentId,
    required this.membershipId,
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
    required this.purpose,
    required this.stripePaymentIntentId,
    required this.createdAtUtc,
    required this.paidAtUtc,
    required this.stripeRefundId,
    required this.refundReason,
    required this.refundRequestedAtUtc,
    required this.refundedAtUtc,
    required this.refundFailureReason,
    required this.appointmentStatus,
    required this.appointmentStartUtc,
    required this.appointmentEndUtc,
    required this.appointmentType,
    required this.appointmentIsPaid,
    required this.membershipPlanType,
    required this.totalSessions,
    required this.remainingSessions,
    required this.membershipIsActive,
    required this.membershipExpiresAtUtc,
    required this.canRefund,
    required this.refundUnavailableReason,
  });

  factory AdminPaymentDetailsModel.fromJson(Map<String, dynamic> json) {
    return AdminPaymentDetailsModel(
      id: _toInt(json['id']),
      paymentType: json['paymentType']?.toString() ?? '',
      appointmentId: _toNullableInt(json['appointmentId']),
      membershipId: _toNullableInt(json['membershipId']),
      clientId: _toInt(json['clientId']),
      clientUserId: _toInt(json['clientUserId']),
      clientName: json['clientName']?.toString() ?? '',
      clientEmail: json['clientEmail']?.toString() ?? '',
      therapistId: _toInt(json['therapistId']),
      therapistName: json['therapistName']?.toString() ?? '',
      therapistEmail: json['therapistEmail']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      currency: json['currency']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      stripePaymentIntentId: json['stripePaymentIntentId']?.toString() ?? '',
      createdAtUtc: _toRequiredDateTime(json['createdAtUtc']),
      paidAtUtc: _toNullableDateTime(json['paidAtUtc']),
      stripeRefundId: json['stripeRefundId']?.toString(),
      refundReason: json['refundReason']?.toString(),
      refundRequestedAtUtc: _toNullableDateTime(json['refundRequestedAtUtc']),
      refundedAtUtc: _toNullableDateTime(json['refundedAtUtc']),
      refundFailureReason: json['refundFailureReason']?.toString(),
      appointmentStatus: json['appointmentStatus']?.toString(),
      appointmentStartUtc: _toNullableDateTime(json['appointmentStartUtc']),
      appointmentEndUtc: _toNullableDateTime(json['appointmentEndUtc']),
      appointmentType: json['appointmentType']?.toString(),
      appointmentIsPaid: json['appointmentIsPaid'] as bool?,
      membershipPlanType: json['membershipPlanType']?.toString(),
      totalSessions: _toNullableInt(json['totalSessions']),
      remainingSessions: _toNullableInt(json['remainingSessions']),
      membershipIsActive: json['membershipIsActive'] as bool?,
      membershipExpiresAtUtc: _toNullableDateTime(
        json['membershipExpiresAtUtc'],
      ),
      canRefund: json['canRefund'] == true,
      refundUnavailableReason: json['refundUnavailableReason']?.toString(),
    );
  }

  bool get isAppointmentPayment {
    return paymentType.trim().toLowerCase() == 'appointment';
  }

  bool get isMembershipPayment {
    return paymentType.trim().toLowerCase() == 'membership';
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
