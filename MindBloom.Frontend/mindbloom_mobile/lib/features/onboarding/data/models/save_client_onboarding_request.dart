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
    };
  }

  static String? _nullableText(String? value) {
    final text = value?.trim() ?? '';

    return text.isEmpty ? null : text;
  }
}
