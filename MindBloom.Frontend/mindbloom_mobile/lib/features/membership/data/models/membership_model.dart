class MembershipModel {
  final int id;
  final int therapistId;
  final String therapistName;
  final String planType;
  final int totalSessions;
  final int remainingSessions;
  final double price;
  final bool isActive;
  final DateTime purchasedAtUtc;
  final DateTime? expiresAtUtc;

  MembershipModel({
    required this.id,
    required this.therapistId,
    required this.therapistName,
    required this.planType,
    required this.totalSessions,
    required this.remainingSessions,
    required this.price,
    required this.isActive,
    required this.purchasedAtUtc,
    this.expiresAtUtc,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) {
    return MembershipModel(
      id: json['id'] ?? 0,
      therapistId: json['therapistId'] ?? 0,
      therapistName: json['therapistName'] ?? '',
      planType: json['planType'] ?? '',
      totalSessions: json['totalSessions'] ?? 0,
      remainingSessions: json['remainingSessions'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      isActive: json['isActive'] ?? false,
      purchasedAtUtc: DateTime.parse(json['purchasedAtUtc']),
      expiresAtUtc: json['expiresAtUtc'] == null
          ? null
          : DateTime.parse(json['expiresAtUtc']),
    );
  }
}
