class CreateReviewRequest {
  final int appointmentId;
  final bool shareAuthorDemographics;
  final int rating;
  final String comment;

  CreateReviewRequest({
    required this.appointmentId,
    this.shareAuthorDemographics = false,
    required this.rating,
    required this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'appointmentId': appointmentId,
      'rating': rating,
      'shareAuthorDemographics': shareAuthorDemographics,
      'comment': comment,
    };
  }
}
