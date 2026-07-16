class AdminReviewModel {
  final int id;

  final int appointmentId;

  final String clientName;

  final String clientEmail;

  final String therapistName;

  final String therapistEmail;

  final int rating;

  final String comment;

  final bool hasTherapistReply;

  final bool isDeleted;

  final DateTime createdAtUtc;

  final DateTime? moderatedAtUtc;

  const AdminReviewModel({
    required this.id,
    required this.appointmentId,
    required this.clientName,
    required this.clientEmail,
    required this.therapistName,
    required this.therapistEmail,
    required this.rating,
    required this.comment,
    required this.hasTherapistReply,
    required this.isDeleted,
    required this.createdAtUtc,
    required this.moderatedAtUtc,
  });

  factory AdminReviewModel.fromJson(Map<String, dynamic> json) {
    return AdminReviewModel(
      id: _toInt(json['id']),
      appointmentId: _toInt(json['appointmentId']),
      clientName: json['clientName']?.toString() ?? '',
      clientEmail: json['clientEmail']?.toString() ?? '',
      therapistName: json['therapistName']?.toString() ?? '',
      therapistEmail: json['therapistEmail']?.toString() ?? '',
      rating: _toInt(json['rating']),
      comment: json['comment']?.toString() ?? '',
      hasTherapistReply: json['hasTherapistReply'] == true,
      isDeleted: json['isDeleted'] == true,
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      moderatedAtUtc: json['moderatedAtUtc'] == null
          ? null
          : DateTime.tryParse(json['moderatedAtUtc'].toString())?.toUtc(),
    );
  }

  AdminReviewModel copyWith({bool? isDeleted, DateTime? moderatedAtUtc}) {
    return AdminReviewModel(
      id: id,
      appointmentId: appointmentId,
      clientName: clientName,
      clientEmail: clientEmail,
      therapistName: therapistName,
      therapistEmail: therapistEmail,
      rating: rating,
      comment: comment,
      hasTherapistReply: hasTherapistReply,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAtUtc: createdAtUtc,
      moderatedAtUtc: moderatedAtUtc ?? this.moderatedAtUtc,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
