class PrivacyCurrentVersionsModel {
  final String privacyPolicyVersion;

  final String termsOfServiceVersion;

  final String sensitiveDataProcessingVersion;

  final String sensitiveDataUsageExplanation;

  const PrivacyCurrentVersionsModel({
    required this.privacyPolicyVersion,
    required this.termsOfServiceVersion,
    required this.sensitiveDataProcessingVersion,
    required this.sensitiveDataUsageExplanation,
  });

  factory PrivacyCurrentVersionsModel.fromJson(Map<String, dynamic> json) {
    return PrivacyCurrentVersionsModel(
      privacyPolicyVersion:
          json['privacyPolicyVersion']?.toString().trim() ?? '',

      termsOfServiceVersion:
          json['termsOfServiceVersion']?.toString().trim() ?? '',

      sensitiveDataProcessingVersion:
          json['sensitiveDataProcessingVersion']?.toString().trim() ?? '',

      sensitiveDataUsageExplanation:
          json['sensitiveDataUsageExplanation']?.toString().trim() ?? '',
    );
  }

  String versionFor(String consentType) {
    switch (consentType) {
      case 'PrivacyPolicy':
        return privacyPolicyVersion;

      case 'TermsOfService':
        return termsOfServiceVersion;

      case 'SensitiveDataProcessing':
        return sensitiveDataProcessingVersion;

      default:
        return '';
    }
  }
}
