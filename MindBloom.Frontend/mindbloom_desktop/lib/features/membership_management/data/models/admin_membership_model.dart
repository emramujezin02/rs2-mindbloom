class AdminMembershipModel {
  final int id;

  final int clientId;

  final String clientName;

  final String clientEmail;

  final int therapistId;

  final String therapistName;

  final String therapistEmail;

  final String planType;

  final String membershipStatus;

  final int totalSessions;

  final int remainingSessions;

  final int usedSessions;

  final int reservedSessions;

  final int consumedSessions;

  final int restoredSessions;

  final double price;

  final bool isActive;

  final String paymentStatus;

  final DateTime? purchasedAtUtc;

  final DateTime? expiresAtUtc;

  final DateTime createdAtUtc;

  const AdminMembershipModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.therapistId,
    required this.therapistName,
    required this.therapistEmail,
    required this.planType,
    required this.membershipStatus,
    required this.totalSessions,
    required this.remainingSessions,
    required this.usedSessions,
    required this.reservedSessions,
    required this.consumedSessions,
    required this.restoredSessions,
    required this.price,
    required this.isActive,
    required this.paymentStatus,
    required this.purchasedAtUtc,
    required this.expiresAtUtc,
    required this.createdAtUtc,
  });

  factory AdminMembershipModel.fromJson(Map<String, dynamic> json) {
    return AdminMembershipModel(
      id: json['id'] ?? 0,
      clientId: json['clientId'] ?? 0,
      clientName: json['clientName'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      therapistId: json['therapistId'] ?? 0,
      therapistName: json['therapistName'] ?? '',
      therapistEmail: json['therapistEmail'] ?? '',
      planType: json['planType'] ?? '',
      membershipStatus: json['membershipStatus'] ?? '',
      totalSessions: json['totalSessions'] ?? 0,
      remainingSessions: json['remainingSessions'] ?? 0,
      usedSessions: json['usedSessions'] ?? 0,
      reservedSessions: json['reservedSessions'] ?? 0,
      consumedSessions: json['consumedSessions'] ?? 0,
      restoredSessions: json['restoredSessions'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] ?? false,
      paymentStatus: json['paymentStatus'] ?? '',
      purchasedAtUtc: _parseNullableDate(json['purchasedAtUtc']),
      expiresAtUtc: _parseNullableDate(json['expiresAtUtc']),
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}
