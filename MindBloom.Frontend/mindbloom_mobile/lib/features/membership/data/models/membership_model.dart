class MembershipModel {
  final int id;
  final int therapistId;
  final String therapistName;
  final String planType;
  final int totalSessions;
  final int remainingSessions;
  final double price;
  final bool isActive;
  final bool isPaid;
  final String paymentStatus;
  final DateTime? purchasedAtUtc;
  final DateTime? expiresAtUtc;

  const MembershipModel({
    required this.id,
    required this.therapistId,
    required this.therapistName,
    required this.planType,
    required this.totalSessions,
    required this.remainingSessions,
    required this.price,
    required this.isActive,
    required this.isPaid,
    required this.paymentStatus,
    this.purchasedAtUtc,
    this.expiresAtUtc,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) {
    final purchasedAtValue = json['purchasedAtUtc'];

    final expiresAtValue = json['expiresAtUtc'];

    return MembershipModel(
      id: json['id'] ?? 0,

      therapistId: json['therapistId'] ?? 0,

      therapistName: json['therapistName'] ?? '',

      planType: json['planType'] ?? '',

      totalSessions: json['totalSessions'] ?? 0,

      remainingSessions: json['remainingSessions'] ?? 0,

      price: (json['price'] as num?)?.toDouble() ?? 0,

      isActive: json['isActive'] ?? false,

      isPaid: json['isPaid'] ?? false,

      paymentStatus: json['paymentStatus'] ?? '',

      purchasedAtUtc: purchasedAtValue is String && purchasedAtValue.isNotEmpty
          ? DateTime.tryParse(purchasedAtValue)
          : null,

      expiresAtUtc: expiresAtValue is String && expiresAtValue.isNotEmpty
          ? DateTime.tryParse(expiresAtValue)
          : null,
    );
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

      default:
        return paymentStatus;
    }
  }
}
