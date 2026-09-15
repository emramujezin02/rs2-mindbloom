class ConversationModel {
  final int id;
  final int appointmentId;
  final String otherParticipantName;
  final String? lastMessage;
  final DateTime? lastMessageAtUtc;
  final int unreadCount;
  final bool isClosed;

  const ConversationModel({
    required this.id,
    required this.appointmentId,
    required this.otherParticipantName,
    required this.lastMessage,
    required this.lastMessageAtUtc,
    required this.unreadCount,
    required this.isClosed,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final lastMessageDate = json['lastMessageAtUtc'];

    return ConversationModel(
      id: json['id'] ?? 0,
      appointmentId: json['appointmentId'] ?? 0,
      otherParticipantName: json['otherParticipantName'] ?? '',
      lastMessage: json['lastMessage'],
      lastMessageAtUtc: lastMessageDate is String && lastMessageDate.isNotEmpty
          ? DateTime.tryParse(lastMessageDate)
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      isClosed: json['isClosed'] ?? false,
    );
  }
}
