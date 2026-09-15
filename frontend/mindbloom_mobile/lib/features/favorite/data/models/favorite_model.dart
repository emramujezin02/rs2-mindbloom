class FavoriteModel {
  final int therapistId;
  final String therapistName;
  final String specialization;

  FavoriteModel({
    required this.therapistId,
    required this.therapistName,
    required this.specialization,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      therapistId: json['therapistId'] ?? 0,
      therapistName: json['therapistName'] ?? '',
      specialization: json['specialization'] ?? '',
    );
  }
}
