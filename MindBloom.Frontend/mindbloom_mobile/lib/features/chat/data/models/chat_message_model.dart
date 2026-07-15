class ChatMessageModel {
  final int id;
  final int conversationId;
  final int senderUserId;
  final String senderName;
  final String content;
  final DateTime sentAtUtc;
  final bool isMine;
  final bool isEdited;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.senderName,
    required this.content,
    required this.sentAtUtc,
    required this.isMine,
    required this.isEdited,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] ?? 0,
      conversationId: json['conversationId'] ?? 0,
      senderUserId: json['senderUserId'] ?? 0,
      senderName: json['senderName'] ?? '',
      content: json['content'] ?? '',
      sentAtUtc: DateTime.parse(json['sentAtUtc']),
      isMine: json['isMine'] ?? false,
      isEdited: json['isEdited'] ?? false,
    );
  }
}
