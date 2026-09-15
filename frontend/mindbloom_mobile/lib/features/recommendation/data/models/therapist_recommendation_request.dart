class TherapistRecommendationRequest {
  final List<int> preferredSpecializationIds;
  final List<String> assessmentFocusAreas;
  final List<int> preferredDays;
  final double? maximumPricePerSession;
  final int? minimumExperienceYears;
  final int take;
  final List<int> preferredTherapyApproachIds;

  const TherapistRecommendationRequest({
    this.preferredSpecializationIds = const [],
    this.assessmentFocusAreas = const [],
    this.preferredDays = const [],
    this.maximumPricePerSession,
    this.minimumExperienceYears,
    this.take = 10,
    this.preferredTherapyApproachIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'preferredSpecializationIds': preferredSpecializationIds,
      'assessmentFocusAreas': assessmentFocusAreas,
      'preferredDays': preferredDays,
      'maximumPricePerSession': maximumPricePerSession,
      'minimumExperienceYears': minimumExperienceYears,
      'take': take,
      'preferredTherapyApproachIds': preferredTherapyApproachIds,
    };
  }
}
