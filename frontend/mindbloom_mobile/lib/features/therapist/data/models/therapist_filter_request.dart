enum TherapistExperienceRange {
  all('Sve', null, null),
  early('0–2 godine', 0, 2),
  developing('3–5 godina', 3, 5),
  experienced('6–10 godina', 6, 10),
  senior('Više od 10 godina', 11, 70);

  final String label;
  final int? minimum, maximum;
  const TherapistExperienceRange(this.label, this.minimum, this.maximum);
}

class TherapistFilterRequest {
  final int? locationId, minExperienceYears, maxExperienceYears;
  final bool offersOnline, worksWithChildren;
  final String? searchText;
  final String? specialization;
  final int? therapyApproachId;
  final String? gender;
  final String? language;
  final String? location;
  final String? sessionMode;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final String? availableDay;
  final String? sortBy;
  final String? sortDirection;
  final int pageNumber;
  final int pageSize;

  const TherapistFilterRequest({
    this.locationId,
    this.minExperienceYears,
    this.maxExperienceYears,
    this.offersOnline = false,
    this.worksWithChildren = false,
    this.searchText,
    this.specialization,
    this.therapyApproachId,
    this.gender,
    this.language,
    this.location,
    this.sessionMode,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.availableDay,
    this.sortBy,
    this.sortDirection,
    this.pageNumber = 1,
    this.pageSize = 10,
  });

  TherapistFilterRequest copyWith({int? pageNumber, int? pageSize}) {
    return TherapistFilterRequest(
      locationId: locationId,
      minExperienceYears: minExperienceYears,
      maxExperienceYears: maxExperienceYears,
      offersOnline: offersOnline,
      worksWithChildren: worksWithChildren,
      searchText: searchText,
      specialization: specialization,
      therapyApproachId: therapyApproachId,
      gender: gender,
      language: language,
      location: location,
      sessionMode: sessionMode,
      minPrice: minPrice,
      maxPrice: maxPrice,
      minRating: minRating,
      availableDay: availableDay,
      sortBy: sortBy,
      sortDirection: sortDirection,
      pageNumber: pageNumber ?? this.pageNumber,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  Map<String, String> toQueryParameters() {
    final params = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
    };

    final normalizedSearchText = searchText?.trim();
    if (locationId != null) params['locationId'] = '$locationId';
    if (minExperienceYears != null) {
      params['minExperienceYears'] = '$minExperienceYears';
    }
    if (maxExperienceYears != null) {
      params['maxExperienceYears'] = '$maxExperienceYears';
    }
    if (offersOnline) params['offersOnline'] = 'true';
    if (worksWithChildren) params['worksWithChildren'] = 'true';

    if (normalizedSearchText != null && normalizedSearchText.isNotEmpty) {
      params['searchText'] = normalizedSearchText;
    }

    final normalizedSpecialization = specialization?.trim();

    if (normalizedSpecialization != null &&
        normalizedSpecialization.isNotEmpty) {
      params['specialization'] = normalizedSpecialization;
    }

    if (therapyApproachId != null && therapyApproachId! > 0) {
      params['therapyApproachId'] = therapyApproachId.toString();
    }

    final normalizedGender = gender?.trim();

    if (normalizedGender != null && normalizedGender.isNotEmpty) {
      params['gender'] = normalizedGender;
    }

    final normalizedLanguage = language?.trim();

    if (normalizedLanguage != null && normalizedLanguage.isNotEmpty) {
      params['language'] = normalizedLanguage;
    }

    final normalizedLocation = location?.trim();

    if (normalizedLocation != null && normalizedLocation.isNotEmpty) {
      params['location'] = normalizedLocation;
    }

    final normalizedSessionMode = sessionMode?.trim();

    if (normalizedSessionMode != null && normalizedSessionMode.isNotEmpty) {
      params['sessionMode'] = normalizedSessionMode;
    }

    if (minPrice != null) {
      params['minPrice'] = minPrice.toString();
    }

    if (maxPrice != null) {
      params['maxPrice'] = maxPrice.toString();
    }

    if (minRating != null) {
      params['minRating'] = minRating.toString();
    }

    final normalizedAvailableDay = availableDay?.trim();

    if (normalizedAvailableDay != null && normalizedAvailableDay.isNotEmpty) {
      params['availableDay'] = normalizedAvailableDay;
    }

    final normalizedSortBy = sortBy?.trim();

    if (normalizedSortBy != null && normalizedSortBy.isNotEmpty) {
      params['sortBy'] = normalizedSortBy;
    }

    final normalizedSortDirection = sortDirection?.trim();

    if (normalizedSortDirection != null && normalizedSortDirection.isNotEmpty) {
      params['sortDirection'] = normalizedSortDirection;
    }

    return params;
  }
}
