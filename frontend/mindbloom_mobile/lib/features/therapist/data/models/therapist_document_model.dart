class TherapistDocumentModel {
  final int id;
  final String fileName, contentType;
  final bool isApproved;
  TherapistDocumentModel.fromJson(Map<String, dynamic> json)
    : id = (json['id'] as num).toInt(),
      fileName = json['fileName'] as String,
      contentType = json['contentType'] as String,
      isApproved = json['isApproved'] as bool;
}
