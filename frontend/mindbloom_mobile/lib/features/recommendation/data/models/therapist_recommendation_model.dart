import 'recommendation_reason_model.dart';

class TherapistRecommendationModel {
  final int therapistId;
  final int userId;
  final String fullName;
  final String specialization;
  final double pricePerSession;
  final int experienceYears;
  final String? profileImageUrl;
  final double averageRating;
  final int reviewCount;
  final bool isFavorite;
  final bool hasPreviousAppointment;
  final List<int> availableDays;
  final double score;
  final int matchPercentage;
  final List<RecommendationReasonModel> reasons;

  TherapistRecommendationModel({
    required this.therapistId,
    required this.userId,
    required this.fullName,
    required this.specialization,
    required this.pricePerSession,
    required this.experienceYears,
    required this.profileImageUrl,
    required this.averageRating,
    required this.reviewCount,
    required this.isFavorite,
    required this.hasPreviousAppointment,
    required this.availableDays,
    required this.score,
    required this.matchPercentage,
    required this.reasons,
  });

  factory TherapistRecommendationModel.fromJson(Map<String, dynamic> json) {
    final rawDays = json['availableDays'];
    final rawReasons = json['reasons'];

    return TherapistRecommendationModel(
      therapistId: json['therapistId'] ?? 0,
      userId: json['userId'] ?? 0,
      fullName: json['fullName'] ?? '',
      specialization: json['specialization'] ?? '',
      pricePerSession: (json['pricePerSession'] as num?)?.toDouble() ?? 0,
      experienceYears: json['experienceYears'] ?? 0,
      profileImageUrl: json['profileImageUrl'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['reviewCount'] ?? 0,
      isFavorite: json['isFavorite'] ?? false,
      hasPreviousAppointment: json['hasPreviousAppointment'] ?? false,
      availableDays: rawDays is List
          ? rawDays.map((day) => (day as num).toInt()).toList()
          : [],
      score: (json['score'] as num?)?.toDouble() ?? 0,
      matchPercentage: json['matchPercentage'] ?? 0,
      reasons: rawReasons is List
          ? rawReasons
                .map(
                  (item) => RecommendationReasonModel.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList()
          : [],
    );
  }
}
