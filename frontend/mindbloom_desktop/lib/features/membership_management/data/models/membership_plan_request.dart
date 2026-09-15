class MembershipPlanRequest {
  final int planType;
  final String name;
  final String description;
  final double price;
  final int durationMonths;
  final int includedSessions;
  final double discountPercentage;
  final List<String> benefits;
  final bool isActive;

  const MembershipPlanRequest({
    required this.planType,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMonths,
    required this.includedSessions,
    required this.discountPercentage,
    required this.benefits,
    required this.isActive,
  });

  Map<String, dynamic> toCreateJson() {
    return {
      'planType': planType,
      'name': name.trim(),
      'description': description.trim(),
      'price': price,
      'durationMonths': durationMonths,
      'includedSessions': includedSessions,
      'discountPercentage': discountPercentage,
      'benefits': benefits,
      'isActive': isActive,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name.trim(),
      'description': description.trim(),
      'price': price,
      'durationMonths': durationMonths,
      'includedSessions': includedSessions,
      'discountPercentage': discountPercentage,
      'benefits': benefits,
    };
  }
}
