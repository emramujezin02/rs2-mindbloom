class UpdateReviewRequest {
  final bool? shareAuthorDemographics;
  final int rating;
  final String comment;

  const UpdateReviewRequest({
    this.shareAuthorDemographics,
    required this.rating,
    required this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      if (shareAuthorDemographics != null)
        'shareAuthorDemographics': shareAuthorDemographics,
      'comment': comment,
    };
  }
}
