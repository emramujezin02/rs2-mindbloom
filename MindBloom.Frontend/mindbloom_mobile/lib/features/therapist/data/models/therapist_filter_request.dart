class TherapistFilterRequest {
  final String? name;
  final String? specialization;
  final double? minPrice;
  final double? maxPrice;
  final String? sortBy;

  TherapistFilterRequest({
    this.name,
    this.specialization,
    this.minPrice,
    this.maxPrice,
    this.sortBy,
  });

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};

    if (name != null && name!.trim().isNotEmpty) {
      params['name'] = name!.trim();
    }

    if (specialization != null && specialization!.trim().isNotEmpty) {
      params['specialization'] = specialization!.trim();
    }

    if (minPrice != null) {
      params['minPrice'] = minPrice.toString();
    }

    if (maxPrice != null) {
      params['maxPrice'] = maxPrice.toString();
    }

    if (sortBy != null && sortBy!.isNotEmpty) {
      params['sortBy'] = sortBy!;
    }

    return params;
  }
}
