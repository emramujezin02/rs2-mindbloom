class UpdateReviewRequest {
  final int rating;
  final String comment;

  const UpdateReviewRequest({required this.rating, required this.comment});

  Map<String, dynamic> toJson() {
    return {'rating': rating, 'comment': comment};
  }
}
