class SendChatMessageRequest {
  final int conversationId;
  final String content;

  const SendChatMessageRequest({
    required this.conversationId,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {'conversationId': conversationId, 'content': content};
  }
}
