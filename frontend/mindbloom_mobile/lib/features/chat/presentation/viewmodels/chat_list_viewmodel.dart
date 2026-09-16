import 'package:flutter/foundation.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/conversation_model.dart';
import '../../data/repositories/chat_repository.dart';

class ChatListViewModel extends ChangeNotifier {
  static const int pageSize = 10;

  final ChatRepository repository;

  ChatListViewModel({required this.repository});

  bool isLoading = false;
  bool isLoadingMore = false;
  String? errorMessage;
  String? loadMoreErrorMessage;

  List<ConversationModel> conversations = [];

  int pageNumber = 1;
  int totalPages = 0;

  bool get hasMorePages => pageNumber < totalPages;

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
    loadMoreErrorMessage = null;
    pageNumber = 1;
    notifyListeners();

    try {
      final response = await repository.getMyConversations(
        pageNumber: 1,
        pageSize: pageSize,
      );

      conversations = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
      errorMessage = null;
    } catch (error) {
      errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Razgovore nije moguće učitati.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreConversations() async {
    if (isLoading || isLoadingMore || !hasMorePages) {
      return;
    }

    isLoadingMore = true;
    loadMoreErrorMessage = null;
    notifyListeners();

    try {
      final response = await repository.getMyConversations(
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
      );

      final existingIds =
          conversations.map((conversation) => conversation.id).toSet();

      conversations.addAll(
        response.items.where(
          (conversation) => !existingIds.contains(conversation.id),
        ),
      );

      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
    } catch (error) {
      loadMoreErrorMessage = AppErrorMessage.from(
        error,
        fallback: 'More conversations could not be loaded.',
      );
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadConversations();

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }
}
