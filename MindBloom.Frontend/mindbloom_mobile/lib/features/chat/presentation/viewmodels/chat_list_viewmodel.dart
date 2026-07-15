import 'package:flutter/foundation.dart';

import '../../data/models/conversation_model.dart';
import '../../data/repositories/chat_repository.dart';

class ChatListViewModel extends ChangeNotifier {
  final ChatRepository repository;

  ChatListViewModel({required this.repository});

  bool isLoading = false;

  String? errorMessage;

  List<ConversationModel> conversations = [];

  int get totalUnreadCount {
    return conversations.fold(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );
  }

  Future<void> loadConversations() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      conversations = await repository.getMyConversations();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }
}
