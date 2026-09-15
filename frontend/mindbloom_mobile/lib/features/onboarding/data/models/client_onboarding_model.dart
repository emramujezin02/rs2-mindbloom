class ClientOnboardingModel {
  final bool hasCompletedOnboarding;
  final DateTime? completedAtUtc;

  final List<String> assessmentFocusAreas;

  final String? preferredTherapistGender;
  final String? preferredSessionType;

  final List<String> preferredLanguages;

  final double? minimumPricePerSession;
  final double? maximumPricePerSession;

  final String? location;

  final List<int> preferredDays;

  final List<int> preferredTherapyApproachIds;

  final bool hasAcceptedSensitiveDataProcessing;

  final String? sensitiveDataProcessingVersion;

  final DateTime? sensitiveDataProcessingAcceptedAtUtc;

  final String sensitiveDataUsageExplanation;

  final String currentSensitiveDataProcessingVersion;

  const ClientOnboardingModel({
    required this.hasCompletedOnboarding,
    required this.completedAtUtc,
    required this.assessmentFocusAreas,
    required this.preferredTherapistGender,
    required this.preferredSessionType,
    required this.preferredLanguages,
    required this.minimumPricePerSession,
    required this.maximumPricePerSession,
    required this.location,
    required this.preferredDays,
    required this.preferredTherapyApproachIds,
    required this.hasAcceptedSensitiveDataProcessing,
    required this.sensitiveDataProcessingVersion,
    required this.sensitiveDataProcessingAcceptedAtUtc,
    required this.sensitiveDataUsageExplanation,
    required this.currentSensitiveDataProcessingVersion,
  });

  factory ClientOnboardingModel.fromJson(Map<String, dynamic> json) {
    return ClientOnboardingModel(
      hasCompletedOnboarding: json['hasCompletedOnboarding'] == true,

      completedAtUtc: DateTime.tryParse(
        json['completedAtUtc']?.toString() ?? '',
      ),

      assessmentFocusAreas: _stringList(json['assessmentFocusAreas']),

      preferredTherapistGender: _nullableString(
        json['preferredTherapistGender'],
      ),

      preferredSessionType: _nullableString(json['preferredSessionType']),

      preferredLanguages: _stringList(json['preferredLanguages']),

      minimumPricePerSession: _nullableDouble(json['minimumPricePerSession']),

      maximumPricePerSession: _nullableDouble(json['maximumPricePerSession']),

      location: _nullableString(json['location']),

      preferredDays: _intList(json['preferredDays']),

      preferredTherapyApproachIds: _intList(
        json['preferredTherapyApproachIds'],
      ),

      hasAcceptedSensitiveDataProcessing:
          json['hasAcceptedSensitiveDataProcessing'] == true,

      sensitiveDataProcessingVersion: _nullableString(
        json['sensitiveDataProcessingVersion'],
      ),

      sensitiveDataProcessingAcceptedAtUtc: DateTime.tryParse(
        json['sensitiveDataProcessingAcceptedAtUtc']?.toString() ?? '',
      ),

      sensitiveDataUsageExplanation:
          json['sensitiveDataUsageExplanation']?.toString().trim() ?? '',

      currentSensitiveDataProcessingVersion:
          json['currentSensitiveDataProcessingVersion']?.toString().trim() ??
          '',
    );
  }

  bool get hasAcceptedCurrentSensitiveDataConsent {
    if (!hasAcceptedSensitiveDataProcessing) {
      return false;
    }

    final accepted = sensitiveDataProcessingVersion?.trim() ?? '';

    final current = currentSensitiveDataProcessingVersion.trim();

    return accepted.isNotEmpty && current.isNotEmpty && accepted == current;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<int> _intList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .map((item) {
          if (item is int) {
            return item;
          }

          if (item is num) {
            return item.toInt();
          }

          return int.tryParse(item.toString());
        })
        .whereType<int>()
        .toList();
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? null : text;
  }

  static double? _nullableDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}
