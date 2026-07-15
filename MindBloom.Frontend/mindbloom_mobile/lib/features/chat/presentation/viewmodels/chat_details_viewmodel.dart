import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/chat_message_model.dart';
import '../../data/models/conversation_details_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/services/chat_realtime_service.dart';

class ChatDetailsViewModel extends ChangeNotifier {
  static const int _pageSize = 20;

  final ChatRepository repository;

  late final ChatRealtimeService realtimeService;

  ChatDetailsViewModel({
    required this.repository,
    required ChatRealtimeService Function({
      required void Function(ChatMessageModel message) onMessageReceived,
      required void Function(ChatConnectionStatus status) onStatusChanged,
      required Future<void> Function() onReconnected,
    })
    realtimeServiceFactory,
  }) {
    realtimeService = realtimeServiceFactory(
      onMessageReceived: _addRealtimeMessage,
      onStatusChanged: _setConnectionStatus,
      onReconnected: _refreshAfterReconnect,
    );
  }

  ConversationDetailsModel? conversation;

  List<ChatMessageModel> messages = [];

  bool isLoading = false;

  bool isLoadingMore = false;

  bool isSending = false;

  String? errorMessage;

  int _currentPage = 0;

  int _totalPages = 0;

  ChatConnectionStatus connectionStatus = ChatConnectionStatus.disconnected;

  bool get hasMoreMessages {
    return _currentPage < _totalPages;
  }

  bool get isConnected {
    return connectionStatus == ChatConnectionStatus.connected;
  }

  String get connectionStatusText {
    return switch (connectionStatus) {
      ChatConnectionStatus.connected => 'Live',
      ChatConnectionStatus.connecting => 'Connecting',
      ChatConnectionStatus.reconnecting => 'Reconnecting',
      ChatConnectionStatus.disconnected => 'Offline',
    };
  }

  Future<void> initializeFromAppointment(int appointmentId) async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      conversation = await repository.getOrCreateConversation(appointmentId);

      await _loadFirstPage();

      await repository.markAsRead(conversation!.id);

      await realtimeService.connect(conversation!.id);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<void> initializeFromConversation(
    ConversationDetailsModel initialConversation,
  ) async {
    conversation = initialConversation;

    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await _loadFirstPage();

      await repository.markAsRead(initialConversation.id);

      await realtimeService.connect(initialConversation.id);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<void> _loadFirstPage() async {
    final conversationId = conversation?.id;

    if (conversationId == null) {
      return;
    }

    final response = await repository.getMessages(
      conversationId: conversationId,
      pageNumber: 1,
      pageSize: _pageSize,
    );

    messages = response.items;

    _currentPage = response.pageNumber;

    _totalPages = response.totalPages;
  }

  Future<void> loadOlderMessages() async {
    final conversationId = conversation?.id;

    if (conversationId == null || isLoadingMore || !hasMoreMessages) {
      return;
    }

    isLoadingMore = true;
    errorMessage = null;

    notifyListeners();

    try {
      final nextPage = _currentPage + 1;

      final response = await repository.getMessages(
        conversationId: conversationId,
        pageNumber: nextPage,
        pageSize: _pageSize,
      );

      final existingIds = messages.map((message) => message.id).toSet();

      final olderMessages = response.items
          .where((message) => !existingIds.contains(message.id))
          .toList();

      messages = [...olderMessages, ...messages];

      _currentPage = response.pageNumber;

      _totalPages = response.totalPages;
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoadingMore = false;

      notifyListeners();
    }
  }

  Future<bool> sendMessage(String content) async {
    final conversationId = conversation?.id;

    final normalizedContent = content.trim();

    if (conversationId == null || normalizedContent.isEmpty || isSending) {
      return false;
    }

    if (normalizedContent.length > 2000) {
      errorMessage =
          'Message may contain at most '
          '2000 characters.';

      notifyListeners();

      return false;
    }

    isSending = true;
    errorMessage = null;

    notifyListeners();

    try {
      if (realtimeService.isConnected) {
        await realtimeService.sendMessage(
          conversationId: conversationId,
          content: normalizedContent,
        );
      } else {
        final message = await repository.sendMessage(
          conversationId: conversationId,
          content: normalizedContent,
        );

        _addMessageIfMissing(message);
      }

      return true;
    } catch (error) {
      errorMessage = error.toString();

      return false;
    } finally {
      isSending = false;

      notifyListeners();
    }
  }

  Future<void> _refreshAfterReconnect() async {
    try {
      await _loadFirstPage();

      final conversationId = conversation?.id;

      if (conversationId != null) {
        await repository.markAsRead(conversationId);
      }

      notifyListeners();
    } catch (_) {
      // Polling i sljedeći reconnect
      // ponovo će pokušati učitavanje.
    }
  }

  void _addRealtimeMessage(ChatMessageModel message) {
    final conversationId = conversation?.id;

    if (conversationId == null || message.conversationId != conversationId) {
      return;
    }

    _addMessageIfMissing(message);

    unawaited(repository.markAsRead(conversationId));
  }

  void _addMessageIfMissing(ChatMessageModel message) {
    final exists = messages.any(
      (existingMessage) => existingMessage.id == message.id,
    );

    if (exists) {
      return;
    }

    messages = [...messages, message];

    messages.sort((first, second) {
      final dateComparison = first.sentAtUtc.compareTo(second.sentAtUtc);

      if (dateComparison != 0) {
        return dateComparison;
      }

      return first.id.compareTo(second.id);
    });

    notifyListeners();
  }

  void _setConnectionStatus(ChatConnectionStatus status) {
    connectionStatus = status;

    notifyListeners();
  }

  Future<void> close() async {
    await realtimeService.stop();
  }

  @override
  void dispose() {
    unawaited(realtimeService.stop());

    super.dispose();
  }
}
