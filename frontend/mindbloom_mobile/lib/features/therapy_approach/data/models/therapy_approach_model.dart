class TherapyApproachModel {
  final int id;
  final String name;
  final String description;
  final String? iconUrl;
  final bool isActive;

  const TherapyApproachModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.isActive,
  });

  factory TherapyApproachModel.fromJson(Map<String, dynamic> json) {
    return TherapyApproachModel(
      id: _parseInt(json['id']),
      name: (json['name'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      iconUrl: _parseNullableString(json['iconUrl']),
      isActive: json.containsKey('isActive')
          ? _parseBool(json['isActive'])
          : true,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _parseNullableString(dynamic value) {
    final normalizedValue = value?.toString().trim() ?? '';

    if (normalizedValue.isEmpty) {
      return null;
    }

    return normalizedValue;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final normalizedValue = value?.toString().trim().toLowerCase();

    return normalizedValue == 'true' || normalizedValue == '1';
  }
}
