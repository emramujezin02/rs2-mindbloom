import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../services/session_storage_service.dart';

enum NotificationConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class NotificationRealtimeService {
  final SessionStorageService sessionStorage;

  final Future<void> Function() onNotificationReceived;

  final Future<void> Function() onReconnected;

  final void Function(NotificationConnectionStatus status)
  onConnectionStatusChanged;

  HubConnection? _hubConnection;

  Timer? _manualReconnectTimer;

  bool _isStarting = false;

  bool _manuallyStopped = false;

  NotificationRealtimeService({
    required this.sessionStorage,
    required this.onNotificationReceived,
    required this.onReconnected,
    required this.onConnectionStatusChanged,
  });

  bool get isConnected {
    return _hubConnection?.state == HubConnectionState.Connected;
  }

  Future<void> start() async {
    if (_isStarting || isConnected) {
      return;
    }

    final token = await sessionStorage.getToken();

    if (token == null || token.trim().isEmpty) {
      onConnectionStatusChanged(NotificationConnectionStatus.disconnected);

      return;
    }

    _isStarting = true;
    _manuallyStopped = false;

    onConnectionStatusChanged(NotificationConnectionStatus.connecting);

    try {
      _hubConnection ??= _createHubConnection();

      if (_hubConnection!.state == HubConnectionState.Disconnected) {
        await _hubConnection!.start();
      }

      onConnectionStatusChanged(NotificationConnectionStatus.connected);
    } catch (_) {
      onConnectionStatusChanged(NotificationConnectionStatus.disconnected);

      _scheduleManualReconnect();
    } finally {
      _isStarting = false;
    }
  }

  HubConnection _createHubConnection() {
    final httpOptions = HttpConnectionOptions(
      accessTokenFactory: () async {
        final token = await sessionStorage.getToken();

        return token ?? '';
      },
    );

    final connection = HubConnectionBuilder()
        .withUrl(
          '${ApiConstants.baseUrl}/hubs/notifications',
          options: httpOptions,
        )
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 20000])
        .build();

    connection.on('ReceiveNotification', _handleNotification);

    connection.onreconnecting(({Exception? error}) {
      onConnectionStatusChanged(NotificationConnectionStatus.reconnecting);
    });

    connection.onreconnected(({String? connectionId}) {
      onConnectionStatusChanged(NotificationConnectionStatus.connected);

      unawaited(onReconnected());
    });

    connection.onclose(({Exception? error}) {
      onConnectionStatusChanged(NotificationConnectionStatus.disconnected);

      if (!_manuallyStopped) {
        _scheduleManualReconnect();
      }
    });

    return connection;
  }

  void _handleNotification(List<Object?>? arguments) {
    /*
     * Ne koristimo podatke direktno iz SignalR poruke
     * kao konačni izvor.
     *
     * Nakon realtime događaja ponovo učitavamo
     * notifikacije preko zaštićenog REST endpointa.
     * Tako dobijamo ID, IsRead i CreatedAtUtc iz baze.
     */
    unawaited(onNotificationReceived());
  }

  void _scheduleManualReconnect() {
    if (_manuallyStopped) {
      return;
    }

    _manualReconnectTimer?.cancel();

    _manualReconnectTimer = Timer(const Duration(seconds: 30), () {
      if (!_manuallyStopped) {
        unawaited(start());
      }
    });
  }

  Future<void> stop() async {
    _manuallyStopped = true;

    _manualReconnectTimer?.cancel();
    _manualReconnectTimer = null;

    final connection = _hubConnection;

    if (connection != null &&
        connection.state != HubConnectionState.Disconnected) {
      try {
        await connection.stop();
      } catch (_) {
        // Session se svakako smije završiti.
      }
    }

    onConnectionStatusChanged(NotificationConnectionStatus.disconnected);
  }
}
