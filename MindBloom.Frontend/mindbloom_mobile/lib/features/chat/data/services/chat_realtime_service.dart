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
    if (arguments == null || arguments.isEmpty) {
      return;
    }

    final firstArgument = arguments.first;

    if (firstArgument is! Map) {
      return;
    }

    final json = Map<String, dynamic>.from(firstArgument);

    onMessageReceived(ChatMessageModel.fromJson(json));
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
  }) async {
    if (!isConnected) {
      throw StateError('Chat connection is not available.');
    }

    await _connection!.invoke('SendMessage', args: [conversationId, content]);
  }

  Future<void> leaveConversation() async {
    final conversationId = _conversationId;

    if (conversationId != null && isConnected) {
      try {
        await _connection!.invoke('LeaveConversation', args: [conversationId]);
      } catch (_) {
        // Konekcija se svakako zatvara.
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
        // Nema dodatne akcije.
      }
    }

    onStatusChanged(ChatConnectionStatus.disconnected);
  }
}
