class MembershipPlanModel {
  final int planType;
  final String name;
  final String description;
  final int totalSessions;
  final int freeSessions;
  final double price;
  final double pricePerSession;
  final int durationMonths;
  final bool isActive;
  final List<String> benefits;

  const MembershipPlanModel({
    required this.planType,
    required this.name,
    required this.description,
    required this.totalSessions,
    required this.freeSessions,
    required this.price,
    required this.pricePerSession,
    required this.durationMonths,
    required this.isActive,
    required this.benefits,
  });

  factory MembershipPlanModel.fromJson(Map<String, dynamic> json) {
    final benefitsValue = json['benefits'];

    return MembershipPlanModel(
      planType: _toInt(json['planType']),
      name: _toString(json['name']),
      description: _toString(json['description']),
      totalSessions: _toInt(json['totalSessions']),
      freeSessions: _toInt(json['freeSessions']),
      price: _toDouble(json['price']),
      pricePerSession: _toDouble(json['pricePerSession']),
      durationMonths: _toInt(json['durationMonths']),
      isActive: _toBool(json['isActive']),
      benefits: benefitsValue is List
          ? benefitsValue
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : const [],
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
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
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
}
