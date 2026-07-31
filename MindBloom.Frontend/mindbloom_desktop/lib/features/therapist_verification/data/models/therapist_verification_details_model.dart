import 'therapist_verification_approach_model.dart';
import 'therapist_verification_audit_model.dart';
import 'therapist_verification_document_model.dart';

class TherapistVerificationDetailsModel {
  final int therapistId;
  final int userId;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final DateTime dateOfBirth;
  final String biography;
  final String education;
  final String specialization;
  final double hourlyRate;
  final int experienceYears;
  final String verificationStatus;
  final String? verificationNotes;
  final String? profileImageUrl;
  final DateTime registeredAtUtc;
  final DateTime? decisionAtUtc;
  final String? decisionByAdminName;

  final List<TherapistVerificationApproachModel> therapyApproaches;

  final List<TherapistVerificationDocumentModel> documents;

  final List<TherapistVerificationAuditModel> auditHistory;

  const TherapistVerificationDetailsModel({
    required this.therapistId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.biography,
    required this.education,
    required this.specialization,
    required this.hourlyRate,
    required this.experienceYears,
    required this.verificationStatus,
    required this.verificationNotes,
    required this.profileImageUrl,
    required this.registeredAtUtc,
    required this.decisionAtUtc,
    required this.decisionByAdminName,
    required this.therapyApproaches,
    required this.documents,
    required this.auditHistory,
  });

  factory TherapistVerificationDetailsModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawApproaches = json['therapyApproaches'];

    final rawDocuments = json['documents'];

    final rawAudits = json['auditHistory'];

    return TherapistVerificationDetailsModel(
      therapistId: (json['therapistId'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString(),
      dateOfBirth:
          DateTime.tryParse(json['dateOfBirth']?.toString() ?? '') ??
          DateTime(1900),
      biography: json['biography']?.toString() ?? '',
      education: json['education']?.toString() ?? '',
      specialization: json['specialization']?.toString() ?? '',
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 0,
      experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
      verificationStatus: json['verificationStatus']?.toString() ?? '',
      verificationNotes: json['verificationNotes']?.toString(),
      profileImageUrl: json['profileImageUrl']?.toString(),
      registeredAtUtc:
          DateTime.tryParse(
            json['registeredAtUtc']?.toString() ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      decisionAtUtc: DateTime.tryParse(
        json['decisionAtUtc']?.toString() ?? '',
      )?.toUtc(),
      decisionByAdminName: json['decisionByAdminName']?.toString(),
      therapyApproaches: rawApproaches is List
          ? rawApproaches
                .whereType<Map<String, dynamic>>()
                .map(TherapistVerificationApproachModel.fromJson)
                .toList()
          : [],
      documents: rawDocuments is List
          ? rawDocuments
                .whereType<Map<String, dynamic>>()
                .map(TherapistVerificationDocumentModel.fromJson)
                .toList()
          : [],
      auditHistory: rawAudits is List
          ? rawAudits
                .whereType<Map<String, dynamic>>()
                .map(TherapistVerificationAuditModel.fromJson)
                .toList()
          : [],
    );
  }
}
