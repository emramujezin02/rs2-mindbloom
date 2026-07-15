class ConversationDetailsModel {
  final int id;
  final int appointmentId;
  final String otherParticipantName;
  final bool isClosed;
  final DateTime createdAtUtc;

  const ConversationDetailsModel({
    required this.id,
    required this.appointmentId,
    required this.otherParticipantName,
    required this.isClosed,
    required this.createdAtUtc,
  });

  factory ConversationDetailsModel.fromJson(Map<String, dynamic> json) {
    return ConversationDetailsModel(
      id: json['id'] ?? 0,
      appointmentId: json['appointmentId'] ?? 0,
      otherParticipantName: json['otherParticipantName'] ?? '',
      isClosed: json['isClosed'] ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
    );
  }
}
