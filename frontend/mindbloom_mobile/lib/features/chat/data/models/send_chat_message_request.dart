class SendChatMessageRequest {
  final int conversationId;
  final String content;
  final String clientMessageId;

  const SendChatMessageRequest({
    required this.conversationId,
    required this.content,
    required this.clientMessageId,
  });

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'content': content,
      'clientMessageId': clientMessageId,
    };
  }
}
