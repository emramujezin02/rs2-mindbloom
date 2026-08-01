class AdminMembershipPlanModel {
  final int id;
  final int planType;
  final String name;
  final String description;
  final double price;
  final int durationMonths;
  final int includedSessions;
  final double discountPercentage;
  final List<String> benefits;
  final bool isActive;
  final bool isDeleted;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;

  const AdminMembershipPlanModel({
    required this.id,
    required this.planType,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMonths,
    required this.includedSessions,
    required this.discountPercentage,
    required this.benefits,
    required this.isActive,
    required this.isDeleted,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  factory AdminMembershipPlanModel.fromJson(Map<String, dynamic> json) {
    final rawBenefits = json['benefits'] as List<dynamic>? ?? const [];

    return AdminMembershipPlanModel(
      id: _toInt(json['id']),
      planType: _toInt(json['planType']),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: _toDouble(json['price']),
      durationMonths: _toInt(json['durationMonths']),
      includedSessions: _toInt(json['includedSessions']),
      discountPercentage: _toDouble(json['discountPercentage']),
      benefits: rawBenefits
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      isActive: json['isActive'] == true,
      isDeleted: json['isDeleted'] == true,
      createdAtUtc: _toRequiredDateTime(json['createdAtUtc']),
      updatedAtUtc: _toNullableDateTime(json['updatedAtUtc']),
    );
  }

  String get planTypeLabel {
    switch (planType) {
      case 1:
        return '10 sessions';
      case 2:
        return '20 sessions';
      case 3:
        return '30 sessions';
      default:
        return 'Plan $planType';
    }
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
