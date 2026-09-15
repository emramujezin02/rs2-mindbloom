import '../../../../core/network/api_client.dart';
import '../models/chat_message_model.dart';
import '../models/chat_message_paged_response.dart';
import '../models/conversation_details_model.dart';
import '../models/conversation_model.dart';
import '../models/send_chat_message_request.dart';

class ChatApiService {
  final ApiClient apiClient;

  ChatApiService({required this.apiClient});

  Future<List<ConversationModel>> getMyConversations() async {
    final response = await apiClient.get('/Chat/conversations');

    return (response as List)
        .whereType<Map<String, dynamic>>()
        .map(ConversationModel.fromJson)
        .toList();
  }

  Future<ConversationDetailsModel> getOrCreateConversation(
    int appointmentId,
  ) async {
    final response = await apiClient.post(
      '/Chat/appointments/'
      '$appointmentId/conversation',
    );

    return ConversationDetailsModel.fromJson(response as Map<String, dynamic>);
  }

  Future<ChatMessagePagedResponse> getMessages({
    required int conversationId,
    required int pageNumber,
    required int pageSize,
  }) async {
    final response = await apiClient.get(
      '/Chat/conversations/'
      '$conversationId/messages'
      '?pageNumber=$pageNumber'
      '&pageSize=$pageSize',
    );

    return ChatMessagePagedResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<ChatMessageModel> sendMessage(SendChatMessageRequest request) async {
    final response = await apiClient.post(
      '/Chat/messages',
      body: request.toJson(),
    );

    return ChatMessageModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> markAsRead(int conversationId) async {
    await apiClient.put(
      '/Chat/conversations/'
      '$conversationId/read',
    );
  }
}
