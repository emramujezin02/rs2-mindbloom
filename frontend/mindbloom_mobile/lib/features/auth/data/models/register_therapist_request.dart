import 'register_request.dart';

class TherapistRegistrationDetails {
  final int? specializationId;
  final int? locationId;
  final bool worksWithChildren;
  final String specialization, biography, country, city, address;
  final double hourlyRate;
  final int experienceYears;
  final bool offersOnline, offersInPerson;

  const TherapistRegistrationDetails({
    this.specializationId,
    this.locationId,
    this.worksWithChildren = false,
    required this.specialization,
    required this.biography,
    required this.country,
    required this.city,
    required this.address,
    required this.hourlyRate,
    required this.experienceYears,
    required this.offersOnline,
    required this.offersInPerson,
  });

  Map<String, dynamic> toJson() => {
    'specializationId': specializationId,
    'locationId': locationId,
    'worksWithChildren': worksWithChildren,
    'specialization': specialization,
    'biography': biography,
    'country': country,
    'city': city,
    'address': address,
    'hourlyRate': hourlyRate,
    'experienceYears': experienceYears,
    'offersOnline': offersOnline,
    'offersInPerson': offersInPerson,
  };
}

class RegisterTherapistRequest {
  final RegisterRequest account;
  final TherapistRegistrationDetails details;
  const RegisterTherapistRequest({
    required this.account,
    required this.details,
  });
  Map<String, dynamic> toJson() => {...account.toJson(), ...details.toJson()};
}

class RegisterTherapistResponse {
  final int userId, therapistId;
  final String email, verificationStatus, message;
  RegisterTherapistResponse.fromJson(Map<String, dynamic> json)
    : userId = (json['userId'] as num).toInt(),
      therapistId = (json['therapistId'] as num).toInt(),
      email = json['email'] as String,
      verificationStatus = json['verificationStatus'] as String,
      message = json['message'] as String;
}
