class TherapistVerificationListModel {
  final int therapistId;
  final int userId;
  final String fullName;
  final String email;
  final String specialization;
  final int experienceYears;
  final String verificationStatus;
  final String? profileImageUrl;
  final int documentCount;
  final DateTime registeredAtUtc;

  const TherapistVerificationListModel({
    required this.therapistId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.specialization,
    required this.experienceYears,
    required this.verificationStatus,
    required this.profileImageUrl,
    required this.documentCount,
    required this.registeredAtUtc,
  });

  factory TherapistVerificationListModel.fromJson(Map<String, dynamic> json) {
    return TherapistVerificationListModel(
      therapistId: (json['therapistId'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      specialization: json['specialization']?.toString() ?? '',
      experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
      verificationStatus: json['verificationStatus']?.toString() ?? '',
      profileImageUrl: json['profileImageUrl']?.toString(),
      documentCount: (json['documentCount'] as num?)?.toInt() ?? 0,
      registeredAtUtc:
          DateTime.tryParse(
            json['registeredAtUtc']?.toString() ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
