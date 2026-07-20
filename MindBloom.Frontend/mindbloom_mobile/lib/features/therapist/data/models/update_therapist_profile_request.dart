class UpdateTherapistProfileRequest {
  final String biography;
  final String specialization;
  final int experienceYears;
  final double hourlyRate;
  final String location;
  final List<String> languages;

  const UpdateTherapistProfileRequest({
    required this.biography,
    required this.specialization,
    required this.experienceYears,
    required this.hourlyRate,
    required this.location,
    required this.languages,
  });

  Map<String, dynamic> toJson() {
    return {
      'biography': biography.trim(),
      'specialization': specialization.trim(),
      'experienceYears': experienceYears,
      'hourlyRate': hourlyRate,
      'location': location.trim(),
      'languages': languages
          .map((language) => language.trim())
          .where((language) => language.isNotEmpty)
          .toSet()
          .toList(),
    };
  }
}
