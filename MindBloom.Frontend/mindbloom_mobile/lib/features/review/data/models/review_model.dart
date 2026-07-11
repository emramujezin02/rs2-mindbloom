class ReviewModel {
  final int id;
  final int? therapistId;
  final int? appointmentId;
  final String clientName;
  final String therapistName;
  final int rating;
  final String comment;
  final DateTime createdAtUtc;
  final String? therapistReply;
  final DateTime? therapistReplyCreatedAtUtc;

  ReviewModel({
    required this.id,
    this.therapistId,
    this.appointmentId,
    required this.clientName,
    required this.therapistName,
    required this.rating,
    required this.comment,
    required this.createdAtUtc,
    this.therapistReply,
    this.therapistReplyCreatedAtUtc,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? 0,
      therapistId: json['therapistId'],
      appointmentId: json['appointmentId'],
      clientName: json['clientName'] ?? '',
      therapistName: json['therapistName'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
      therapistReply: json['therapistReply'],
      therapistReplyCreatedAtUtc: json['therapistReplyCreatedAtUtc'] == null
          ? null
          : DateTime.parse(json['therapistReplyCreatedAtUtc']),
    );
  }
}
