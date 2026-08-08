class CurrentConsentVersions {
  final String privacyPolicyVersion;
  final String termsOfServiceVersion;
  final String sensitiveDataProcessingVersion;
  final String sensitiveDataUsageExplanation;

  const CurrentConsentVersions({
    required this.privacyPolicyVersion,
    required this.termsOfServiceVersion,
    required this.sensitiveDataProcessingVersion,
    required this.sensitiveDataUsageExplanation,
  });

  factory CurrentConsentVersions.fromJson(Map<String, dynamic> json) {
    return CurrentConsentVersions(
      privacyPolicyVersion: json['privacyPolicyVersion']?.toString() ?? '',
      termsOfServiceVersion: json['termsOfServiceVersion']?.toString() ?? '',
      sensitiveDataProcessingVersion:
          json['sensitiveDataProcessingVersion']?.toString() ?? '',
      sensitiveDataUsageExplanation:
          json['sensitiveDataUsageExplanation']?.toString() ?? '',
    );
  }

  bool get hasRegistrationVersions =>
      privacyPolicyVersion.trim().isNotEmpty &&
      termsOfServiceVersion.trim().isNotEmpty;
}
