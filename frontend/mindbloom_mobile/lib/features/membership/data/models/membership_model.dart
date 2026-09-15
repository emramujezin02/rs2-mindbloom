class MembershipModel {
  final int id;
  final int therapistId;
  final String therapistName;
  final String planType;
  final String planName;
  final int totalSessions;
  final int remainingSessions;
  final int usedSessions;
  final double price;
  final bool isActive;
  final bool isPaid;
  final bool isExpired;
  final String paymentStatus;
  final DateTime? purchasedAtUtc;
  final DateTime? expiresAtUtc;

  const MembershipModel({
    required this.id,
    required this.therapistId,
    required this.therapistName,
    required this.planType,
    required this.planName,
    required this.totalSessions,
    required this.remainingSessions,
    required this.usedSessions,
    required this.price,
    required this.isActive,
    required this.isPaid,
    required this.isExpired,
    required this.paymentStatus,
    this.purchasedAtUtc,
    this.expiresAtUtc,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) {
    return MembershipModel(
      id: _toInt(json['id']),
      therapistId: _toInt(json['therapistId']),
      therapistName: _toString(json['therapistName']),
      planType: _toString(json['planType']),
      planName: _toString(json['planName']),
      totalSessions: _toInt(json['totalSessions']),
      remainingSessions: _toInt(json['remainingSessions']),
      usedSessions: _toInt(json['usedSessions']),
      price: _toDouble(json['price']),
      isActive: _toBool(json['isActive']),
      isPaid: _toBool(json['isPaid']),
      isExpired: _toBool(json['isExpired']),
      paymentStatus: _toString(json['paymentStatus']),
      purchasedAtUtc: _toNullableDateTime(json['purchasedAtUtc']),
      expiresAtUtc: _toNullableDateTime(json['expiresAtUtc']),
    );
  }

  String get displayPlanName {
    if (planName.isNotEmpty) {
      return planName;
    }

    switch (planType.trim().toLowerCase()) {
      case 'tensessions':
        return '10 sessions package';
      case 'twentysessions':
        return '20 sessions package';
      case 'thirtysessions':
        return '30 sessions package';
      default:
        return planType;
    }
  }

  String get displayPaymentStatus {
    switch (paymentStatus.trim().toLowerCase()) {
      case 'pending':
        return 'Payment pending';
      case 'paid':
        return 'Paid';
      case 'failed':
        return 'Payment failed';
      case 'refunded':
        return 'Refunded';
      case 'notcreated':
        return 'Payment not created';
      default:
        return paymentStatus;
    }
  }

  String get displayMembershipStatus {
    if (isActive) {
      return 'Active';
    }

    if (isExpired) {
      return 'Expired';
    }

    if (isPaid && remainingSessions <= 0) {
      return 'Used';
    }

    if (!isPaid) {
      return 'Awaiting payment';
    }

    return 'Inactive';
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

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    return value?.toString().trim().toLowerCase() == 'true';
  }

  static String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}
