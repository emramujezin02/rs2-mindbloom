import 'chat_message_model.dart';

class ChatMessagePagedResponse {
  final List<ChatMessageModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  const ChatMessagePagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  bool get hasMorePages {
    return pageNumber < totalPages;
  }

  factory ChatMessagePagedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return ChatMessagePagedResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(ChatMessageModel.fromJson)
                .toList()
          : [],
      pageNumber: json['pageNumber'] ?? 1,
      pageSize: json['pageSize'] ?? 20,
      totalCount: json['totalCount'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}
