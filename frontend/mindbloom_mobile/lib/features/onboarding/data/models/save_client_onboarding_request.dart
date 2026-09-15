class SaveClientOnboardingRequest {
  final List<String> assessmentFocusAreas;

  final String? preferredTherapistGender;

  final String? preferredSessionType;

  final List<String> preferredLanguages;

  final double? minimumPricePerSession;
  final double? maximumPricePerSession;

  final String? location;

  final List<int> preferredDays;

  final List<int> preferredTherapyApproachIds;

  final bool completeOnboarding;

  final bool acceptSensitiveDataProcessing;

  final String sensitiveDataProcessingVersion;

  const SaveClientOnboardingRequest({
    required this.assessmentFocusAreas,
    required this.preferredTherapistGender,
    required this.preferredSessionType,
    required this.preferredLanguages,
    required this.minimumPricePerSession,
    required this.maximumPricePerSession,
    required this.location,
    required this.preferredDays,
    required this.preferredTherapyApproachIds,
    required this.acceptSensitiveDataProcessing,
    required this.sensitiveDataProcessingVersion,
    this.completeOnboarding = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'assessmentFocusAreas': assessmentFocusAreas,

      'preferredTherapistGender': _nullableText(preferredTherapistGender),

      'preferredSessionType': _nullableText(preferredSessionType),

      'preferredLanguages': preferredLanguages,

      'minimumPricePerSession': minimumPricePerSession,

      'maximumPricePerSession': maximumPricePerSession,

      'location': _nullableText(location),

      'preferredDays': preferredDays,

      'preferredTherapyApproachIds': preferredTherapyApproachIds,

      'completeOnboarding': completeOnboarding,

      'acceptSensitiveDataProcessing': acceptSensitiveDataProcessing,

      'sensitiveDataProcessingVersion': sensitiveDataProcessingVersion,
    };
  }

  static String? _nullableText(String? value) {
    final text = value?.trim() ?? '';

    return text.isEmpty ? null : text;
  }
}
