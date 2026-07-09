class MembershipPlanModel {
  final int planType;
  final String name;
  final int totalSessions;
  final int freeSessions;
  final double price;
  final double pricePerSession;

  MembershipPlanModel({
    required this.planType,
    required this.name,
    required this.totalSessions,
    required this.freeSessions,
    required this.price,
    required this.pricePerSession,
  });

  factory MembershipPlanModel.fromJson(Map<String, dynamic> json) {
    return MembershipPlanModel(
      planType: json['planType'] ?? 0,
      name: json['name'] ?? '',
      totalSessions: json['totalSessions'] ?? 0,
      freeSessions: json['freeSessions'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      pricePerSession: (json['pricePerSession'] ?? 0).toDouble(),
    );
  }
}
