class TherapistFilterRequest {
  final String? name;
  final String? specialization;
  final int? therapyApproachId;
  final double? minPrice;
  final double? maxPrice;
  final String? sortBy;

  const TherapistFilterRequest({
    this.name,
    this.specialization,
    this.therapyApproachId,
    this.minPrice,
    this.maxPrice,
    this.sortBy,
  });

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};

    final normalizedName = name?.trim();

    if (normalizedName != null && normalizedName.isNotEmpty) {
      params['name'] = normalizedName;
    }

    final normalizedSpecialization = specialization?.trim();

    if (normalizedSpecialization != null &&
        normalizedSpecialization.isNotEmpty) {
      params['specialization'] = normalizedSpecialization;
    }

    if (therapyApproachId != null && therapyApproachId! > 0) {
      params['therapyApproachId'] = therapyApproachId.toString();
    }

    if (minPrice != null) {
      params['minPrice'] = minPrice.toString();
    }

    if (maxPrice != null) {
      params['maxPrice'] = maxPrice.toString();
    }

    final normalizedSortBy = sortBy?.trim();

    if (normalizedSortBy != null && normalizedSortBy.isNotEmpty) {
      params['sortBy'] = normalizedSortBy;
    }

    return params;
  }
}
