class ReviewModel {
  final int id;
  final String clientName;
  final int rating;
  final String comment;
  final DateTime createdAtUtc;
  final String? therapistReply;

  ReviewModel({
    required this.id,
    required this.clientName,
    required this.rating,
    required this.comment,
    required this.createdAtUtc,
    this.therapistReply,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'],
      clientName: json['clientName'],
      rating: json['rating'],
      comment: json['comment'],
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
      therapistReply: json['therapistReply'],
    );
  }
}
