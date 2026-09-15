class TherapistVerificationDocumentModel {
  final int id;
  final String fileName;
  final String filePath;
  final String contentType;
  final bool isApproved;
  final DateTime createdAtUtc;

  const TherapistVerificationDocumentModel({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.contentType,
    required this.isApproved,
    required this.createdAtUtc,
  });

  factory TherapistVerificationDocumentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TherapistVerificationDocumentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fileName: json['fileName']?.toString() ?? '',
      filePath: json['filePath']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? '',
      isApproved: json['isApproved'] == true,
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
