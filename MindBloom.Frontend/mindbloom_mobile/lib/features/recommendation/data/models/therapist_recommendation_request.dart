class TherapistRecommendationRequest {
  final List<int> preferredSpecializationIds;
  final List<String> assessmentFocusAreas;
  final List<int> preferredDays;
  final double? maximumPricePerSession;
  final int? minimumExperienceYears;
  final int take;

  const TherapistRecommendationRequest({
    this.preferredSpecializationIds = const [],
    this.assessmentFocusAreas = const [],
    this.preferredDays = const [],
    this.maximumPricePerSession,
    this.minimumExperienceYears,
    this.take = 10,
  });

  Map<String, dynamic> toJson() {
    return {
      'preferredSpecializationIds': preferredSpecializationIds,
      'assessmentFocusAreas': assessmentFocusAreas,
      'preferredDays': preferredDays,
      'maximumPricePerSession': maximumPricePerSession,
      'minimumExperienceYears': minimumExperienceYears,
      'take': take,
    };
  }
}
