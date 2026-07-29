import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../services/session_storage_service.dart';
import '../models/chat_message_model.dart';

enum ChatConnectionStatus { disconnected, connecting, connected, reconnecting }

class ChatRealtimeService {
  final SessionStorageService sessionStorage;

  final void Function(ChatMessageModel message) onMessageReceived;

  final void Function(ChatConnectionStatus status) onStatusChanged;

  final Future<void> Function() onReconnected;

  final void Function(int conversationId, bool isTyping) onTypingChanged;

  final void Function(int conversationId, DateTime readAtUtc)
  onConversationRead;

  HubConnection? _connection;

  Timer? _manualReconnectTimer;

  int? _conversationId;

  bool _isStarting = false;

  bool _manuallyStopped = false;

  ChatRealtimeService({
    required this.sessionStorage,
    required this.onMessageReceived,
    required this.onStatusChanged,
    required this.onReconnected,
    required this.onTypingChanged,
    required this.onConversationRead,
  });

  bool get isConnected {
    return _connection?.state == HubConnectionState.Connected;
  }

  Future<void> connect(int conversationId) async {
    _conversationId = conversationId;

    if (_isStarting) {
      return;
    }

    if (isConnected) {
      await joinConversation(conversationId);

      return;
    }

    final token = await sessionStorage.getToken();

    if (token == null || token.trim().isEmpty) {
      onStatusChanged(ChatConnectionStatus.disconnected);

      return;
    }

    _isStarting = true;
    _manuallyStopped = false;

    onStatusChanged(ChatConnectionStatus.connecting);

    try {
      _connection ??= _createConnection();

      if (_connection!.state == HubConnectionState.Disconnected) {
        await _connection!.start();
      }

      await joinConversation(conversationId);

      onStatusChanged(ChatConnectionStatus.connected);
    } catch (_) {
      onStatusChanged(ChatConnectionStatus.disconnected);

      _scheduleReconnect();
    } finally {
      _isStarting = false;
    }
  }

  HubConnection _createConnection() {
    final options = HttpConnectionOptions(
      accessTokenFactory: () async {
        return await sessionStorage.getToken() ?? '';
      },
    );

    final connection = HubConnectionBuilder()
        .withUrl(
          '${ApiConstants.baseUrl}'
          '/hubs/chat',
          options: options,
        )
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 20000])
        .build();

    connection.on('ReceiveMessage', _handleMessage);

    connection.on('TypingChanged', _handleTypingChanged);

    connection.on('ConversationRead', _handleConversationRead);

    connection.onreconnecting(({Exception? error}) {
      onStatusChanged(ChatConnectionStatus.reconnecting);
    });

    connection.onreconnected(({String? connectionId}) {
      unawaited(_handleReconnected());
    });

    connection.onclose(({Exception? error}) {
      onStatusChanged(ChatConnectionStatus.disconnected);

      if (!_manuallyStopped) {
        _scheduleReconnect();
      }
    });

    return connection;
  }

  Future<void> _handleReconnected() async {
    final conversationId = _conversationId;

    if (conversationId == null) {
      return;
    }

    try {
      await joinConversation(conversationId);

      onStatusChanged(ChatConnectionStatus.connected);

      await onReconnected();
    } catch (_) {
      onStatusChanged(ChatConnectionStatus.disconnected);

      _scheduleReconnect();
    }
  }

  void _handleMessage(List<Object?>? arguments) {
    final json = _firstJsonArgument(arguments);

    if (json == null) {
      return;
    }

    onMessageReceived(ChatMessageModel.fromJson(json));
  }

  void _handleTypingChanged(List<Object?>? arguments) {
    final json = _firstJsonArgument(arguments);

    if (json == null) {
      return;
    }

    final conversationId = _toInt(json['conversationId']);

    final isTyping = json['isTyping'] == true;

    if (conversationId <= 0) {
      return;
    }

    onTypingChanged(conversationId, isTyping);
  }

  void _handleConversationRead(List<Object?>? arguments) {
    final json = _firstJsonArgument(arguments);

    if (json == null) {
      return;
    }

    final conversationId = _toInt(json['conversationId']);

    final readAtUtc = DateTime.tryParse(json['readAtUtc']?.toString() ?? '');

    if (conversationId <= 0 || readAtUtc == null) {
      return;
    }

    onConversationRead(conversationId, readAtUtc);
  }

  Map<String, dynamic>? _firstJsonArgument(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) {
      return null;
    }

    final firstArgument = arguments.first;

    if (firstArgument is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(firstArgument);
  }

  Future<void> joinConversation(int conversationId) async {
    if (!isConnected) {
      return;
    }

    await _connection!.invoke('JoinConversation', args: [conversationId]);
  }

  Future<void> sendMessage({
    required int conversationId,
    required String content,
    required String clientMessageId,
  }) async {
    if (!isConnected) {
      throw StateError('Chat connection is not available.');
    }

    await _connection!.invoke(
      'SendMessage',
      args: [conversationId, content, clientMessageId],
    );
  }

  Future<void> setTyping({
    required int conversationId,
    required bool isTyping,
  }) async {
    if (!isConnected) {
      return;
    }

    await _connection!.invoke('SetTyping', args: [conversationId, isTyping]);
  }

  Future<void> markAsRead(int conversationId) async {
    if (!isConnected) {
      return;
    }

    await _connection!.invoke('MarkAsRead', args: [conversationId]);
  }

  Future<void> leaveConversation() async {
    final conversationId = _conversationId;

    if (conversationId != null && isConnected) {
      try {
        await setTyping(conversationId: conversationId, isTyping: false);

        await _connection!.invoke('LeaveConversation', args: [conversationId]);
      } catch (_) {
        // Connection is being closed.
      }
    }

    _conversationId = null;
  }

  void _scheduleReconnect() {
    if (_manuallyStopped) {
      return;
    }

    _manualReconnectTimer?.cancel();

    _manualReconnectTimer = Timer(const Duration(seconds: 20), () {
      final conversationId = _conversationId;

      if (!_manuallyStopped && conversationId != null) {
        unawaited(connect(conversationId));
      }
    });
  }

  Future<void> stop() async {
    _manuallyStopped = true;

    _manualReconnectTimer?.cancel();
    _manualReconnectTimer = null;

    await leaveConversation();

    final connection = _connection;

    if (connection != null &&
        connection.state != HubConnectionState.Disconnected) {
      try {
        await connection.stop();
      } catch (_) {
        // No additional action is needed.
      }
    }

    onStatusChanged(ChatConnectionStatus.disconnected);
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
