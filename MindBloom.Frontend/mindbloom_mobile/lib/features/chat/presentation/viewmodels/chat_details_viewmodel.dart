import 'dart:async';
import 'dart:math';

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
      errorMessage = _normalizeError(error);
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
      errorMessage = _normalizeError(error);
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

    _mergeFirstPage(response.items);

    _currentPage = response.pageNumber;

    _totalPages = response.totalPages;
  }

  void _mergeFirstPage(List<ChatMessageModel> serverMessages) {
    final serverClientIds = serverMessages
        .map((message) => message.clientMessageId)
        .whereType<String>()
        .toSet();

    final localTransientMessages = messages.where((message) {
      final clientId = message.clientMessageId;

      return message.deliveryStatus != ChatMessageDeliveryStatus.sent &&
          (clientId == null || !serverClientIds.contains(clientId));
    }).toList();

    messages = [...serverMessages, ...localTransientMessages];

    _sortMessages();
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

      final existingServerIds = messages
          .where((message) => message.id > 0)
          .map((message) => message.id)
          .toSet();

      final olderMessages = response.items
          .where((message) => !existingServerIds.contains(message.id))
          .toList();

      messages = [...olderMessages, ...messages];

      _sortMessages();

      _currentPage = response.pageNumber;

      _totalPages = response.totalPages;
    } catch (error) {
      errorMessage = _normalizeError(error);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage(String content) async {
    final conversationId = conversation?.id;

    final normalizedContent = content.trim();

    if (conversationId == null || normalizedContent.isEmpty) {
      return false;
    }

    if (conversation?.isClosed == true) {
      errorMessage = 'This conversation is closed.';

      notifyListeners();

      return false;
    }

    if (normalizedContent.length > 2000) {
      errorMessage =
          'Message may contain at most '
          '2000 characters.';

      notifyListeners();

      return false;
    }

    errorMessage = null;

    final clientMessageId = _createClientMessageId();

    final optimisticMessage = ChatMessageModel.optimistic(
      conversationId: conversationId,
      content: normalizedContent,
      clientMessageId: clientMessageId,
    );

    messages = [...messages, optimisticMessage];

    _sortMessages();

    notifyListeners();

    try {
      if (realtimeService.isConnected) {
        await realtimeService.sendMessage(
          conversationId: conversationId,
          content: normalizedContent,
          clientMessageId: clientMessageId,
        );
      } else {
        final serverMessage = await repository.sendMessage(
          conversationId: conversationId,
          content: normalizedContent,
          clientMessageId: clientMessageId,
        );

        _reconcileMessage(serverMessage);
      }

      return true;
    } catch (error) {
      _markMessageAsFailed(clientMessageId, _normalizeError(error));

      return false;
    }
  }

  Future<bool> retryMessage(ChatMessageModel message) async {
    if (!message.hasFailed) {
      return false;
    }

    final clientMessageId = message.clientMessageId;

    final conversationId = conversation?.id;

    if (clientMessageId == null || conversationId == null) {
      return false;
    }

    _updateMessage(
      clientMessageId,
      message.copyWith(
        deliveryStatus: ChatMessageDeliveryStatus.sending,
        clearSendingError: true,
      ),
    );

    try {
      if (realtimeService.isConnected) {
        await realtimeService.sendMessage(
          conversationId: conversationId,
          content: message.content,
          clientMessageId: clientMessageId,
        );
      } else {
        final serverMessage = await repository.sendMessage(
          conversationId: conversationId,
          content: message.content,
          clientMessageId: clientMessageId,
        );

        _reconcileMessage(serverMessage);
      }

      return true;
    } catch (error) {
      _markMessageAsFailed(clientMessageId, _normalizeError(error));

      return false;
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
      // Sljedeći reconnect ponovo pokušava.
    }
  }

  void _addRealtimeMessage(ChatMessageModel message) {
    final conversationId = conversation?.id;

    if (conversationId == null || message.conversationId != conversationId) {
      return;
    }

    _reconcileMessage(message);

    unawaited(repository.markAsRead(conversationId));
  }

  void _reconcileMessage(ChatMessageModel serverMessage) {
    final clientMessageId = serverMessage.clientMessageId;

    if (clientMessageId != null) {
      final localIndex = messages.indexWhere(
        (message) => message.clientMessageId == clientMessageId,
      );

      if (localIndex >= 0) {
        messages[localIndex] = serverMessage.copyWith(
          deliveryStatus: ChatMessageDeliveryStatus.sent,
          clearSendingError: true,
        );

        _sortMessages();
        notifyListeners();

        return;
      }
    }

    final serverMessageExists = messages.any(
      (message) => message.id == serverMessage.id && serverMessage.id > 0,
    );

    if (serverMessageExists) {
      return;
    }

    messages = [...messages, serverMessage];

    _sortMessages();
    notifyListeners();
  }

  void _markMessageAsFailed(String clientMessageId, String error) {
    final index = messages.indexWhere(
      (message) => message.clientMessageId == clientMessageId,
    );

    if (index < 0) {
      return;
    }

    messages[index] = messages[index].copyWith(
      deliveryStatus: ChatMessageDeliveryStatus.failed,
      sendingError: error,
    );

    notifyListeners();
  }

  void _updateMessage(String clientMessageId, ChatMessageModel updatedMessage) {
    final index = messages.indexWhere(
      (message) => message.clientMessageId == clientMessageId,
    );

    if (index < 0) {
      return;
    }

    messages[index] = updatedMessage;

    notifyListeners();
  }

  void _sortMessages() {
    messages.sort((first, second) {
      final dateComparison = first.sentAtUtc.compareTo(second.sentAtUtc);

      if (dateComparison != 0) {
        return dateComparison;
      }

      return first.id.compareTo(second.id);
    });
  }

  String _createClientMessageId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;

    final random = Random.secure().nextInt(0x7fffffff);

    return 'mobile-$timestamp-$random';
  }

  void _setConnectionStatus(ChatConnectionStatus status) {
    connectionStatus = status;

    notifyListeners();
  }

  String _normalizeError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
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
