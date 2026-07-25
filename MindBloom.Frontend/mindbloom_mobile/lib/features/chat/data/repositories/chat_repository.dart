import '../models/chat_message_model.dart';
import '../models/chat_message_paged_response.dart';
import '../models/conversation_details_model.dart';
import '../models/conversation_model.dart';
import '../models/send_chat_message_request.dart';
import '../services/chat_api_service.dart';

class ChatRepository {
  final ChatApiService apiService;

  ChatRepository({required this.apiService});

  Future<List<ConversationModel>> getMyConversations() {
    return apiService.getMyConversations();
  }

  Future<ConversationDetailsModel> getOrCreateConversation(int appointmentId) {
    return apiService.getOrCreateConversation(appointmentId);
  }

  Future<ChatMessagePagedResponse> getMessages({
    required int conversationId,
    required int pageNumber,
    required int pageSize,
  }) {
    return apiService.getMessages(
      conversationId: conversationId,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
  }

  Future<ChatMessageModel> sendMessage({
    required int conversationId,
    required String content,
    required String clientMessageId,
  }) {
    return apiService.sendMessage(
      SendChatMessageRequest(
        conversationId: conversationId,
        content: content,
        clientMessageId: clientMessageId,
      ),
    );
  }

  Future<void> markAsRead(int conversationId) {
    return apiService.markAsRead(conversationId);
  }
}
