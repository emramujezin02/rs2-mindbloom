class UserConsentModel {
  final String consentType;
  final String documentVersion;
  final bool isAccepted;
  final DateTime acceptedAtUtc;

  const UserConsentModel({
    required this.consentType,
    required this.documentVersion,
    required this.isAccepted,
    required this.acceptedAtUtc,
  });

  factory UserConsentModel.fromJson(Map<String, dynamic> json) {
    final acceptedAt =
        DateTime.tryParse(json['acceptedAtUtc']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return UserConsentModel(
      consentType: json['consentType']?.toString().trim() ?? '',
      documentVersion: json['documentVersion']?.toString().trim() ?? '',
      isAccepted: json['isAccepted'] == true,
      acceptedAtUtc: acceptedAt,
    );
  }
}
