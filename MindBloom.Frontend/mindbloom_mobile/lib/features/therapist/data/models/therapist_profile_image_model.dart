class TherapistProfileImageModel {
  final String profileImageUrl;

  const TherapistProfileImageModel({required this.profileImageUrl});

  factory TherapistProfileImageModel.fromJson(Map<String, dynamic> json) {
    return TherapistProfileImageModel(
      profileImageUrl: json['profileImageUrl']?.toString() ?? '',
    );
  }
}
