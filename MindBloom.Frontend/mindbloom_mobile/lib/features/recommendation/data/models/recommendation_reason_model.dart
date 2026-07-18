class RecommendationReasonModel {
  final String criterion;
  final double awardedPoints;
  final double maximumPoints;
  final String explanation;

  RecommendationReasonModel({
    required this.criterion,
    required this.awardedPoints,
    required this.maximumPoints,
    required this.explanation,
  });

  factory RecommendationReasonModel.fromJson(Map<String, dynamic> json) {
    return RecommendationReasonModel(
      criterion: json['criterion'] ?? '',
      awardedPoints: (json['awardedPoints'] as num?)?.toDouble() ?? 0,
      maximumPoints: (json['maximumPoints'] as num?)?.toDouble() ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }
}
