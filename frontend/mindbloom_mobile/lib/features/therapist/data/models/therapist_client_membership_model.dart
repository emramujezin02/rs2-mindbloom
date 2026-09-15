class TherapistClientMembershipModel {
  final int id;
  final String planType;
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

  const TherapistClientMembershipModel({
    required this.id,
    required this.planType,
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

  factory TherapistClientMembershipModel.fromJson(Map<String, dynamic> json) {
    return TherapistClientMembershipModel(
      id: _toInt(json['id']),
      planType: _toString(json['planType']),
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
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
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
