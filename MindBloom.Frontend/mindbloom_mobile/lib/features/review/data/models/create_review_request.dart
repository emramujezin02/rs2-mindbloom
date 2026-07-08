class CreateReviewRequest {
  final int appointmentId;
  final int rating;
  final String comment;

  CreateReviewRequest({
    required this.appointmentId,
    required this.rating,
    required this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'appointmentId': appointmentId,
      'rating': rating,
      'comment': comment,
    };
  }
}
