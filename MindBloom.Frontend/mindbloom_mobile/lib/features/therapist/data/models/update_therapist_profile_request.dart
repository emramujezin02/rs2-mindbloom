class UpdateTherapistProfileRequest {
  final String biography;
  final String specialization;
  final int experienceYears;
  final double hourlyRate;
  final String location;
  final String country;
  final String city;
  final String address;
  final bool offersOnline;
  final bool offersInPerson;
  final List<String> languages;
  final List<int> therapyApproachIds;

  const UpdateTherapistProfileRequest({
    required this.biography,
    required this.specialization,
    required this.experienceYears,
    required this.hourlyRate,
    required this.location,
    required this.country,
    required this.city,
    required this.address,
    required this.offersOnline,
    required this.offersInPerson,
    required this.languages,
    required this.therapyApproachIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'biography': biography.trim(),
      'specialization': specialization.trim(),
      'experienceYears': experienceYears,
      'hourlyRate': hourlyRate,
      'location': location.trim(),
      'country': country.trim(),
      'city': city.trim(),
      'address': address.trim(),
      'offersOnline': offersOnline,
      'offersInPerson': offersInPerson,
      'languages': languages
          .map((language) => language.trim())
          .where((language) => language.isNotEmpty)
          .toSet()
          .toList(),
      'therapyApproachIds': therapyApproachIds
          .where((id) => id > 0)
          .toSet()
          .toList(),
    };
  }
}
