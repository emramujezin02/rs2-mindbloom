import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/services/notification_realtime_service.dart';

class NotificationViewModel extends ChangeNotifier {
  final NotificationRepository repository;

  late final NotificationRealtimeService realtimeService;

  NotificationViewModel({
    required this.repository,
    required NotificationRealtimeService Function({
      required Future<void> Function() onNotificationReceived,
      required Future<void> Function() onReconnected,
      required void Function(NotificationConnectionStatus status)
      onConnectionStatusChanged,
    })
    realtimeServiceFactory,
  }) {
    realtimeService = realtimeServiceFactory(
      onNotificationReceived: () async {
        await loadNotifications(showLoading: false);
      },
      onReconnected: () async {
        await loadNotifications(showLoading: false);
      },
      onConnectionStatusChanged: _setConnectionStatus,
    );
  }

  bool isLoading = false;

  bool isRefreshing = false;

  bool isInitialized = false;

  String? error;

  NotificationConnectionStatus connectionStatus =
      NotificationConnectionStatus.disconnected;

  List<NotificationModel> notifications = [];

  Timer? _pollingTimer;

  int get unreadCount {
    return notifications.where((notification) => !notification.isRead).length;
  }

  bool get isRealtimeConnected {
    return connectionStatus == NotificationConnectionStatus.connected;
  }

  String get connectionStatusText {
    return switch (connectionStatus) {
      NotificationConnectionStatus.connected => 'Live',
      NotificationConnectionStatus.connecting => 'Connecting',
      NotificationConnectionStatus.reconnecting => 'Reconnecting',
      NotificationConnectionStatus.disconnected => 'Polling',
    };
  }

  Future<void> initialize() async {
    if (isInitialized) {
      return;
    }

    isInitialized = true;

    await loadNotifications();

    await realtimeService.start();

    _startPolling();
  }

  Future<void> loadNotifications({bool showLoading = true}) async {
    if (isRefreshing) {
      return;
    }

    isRefreshing = true;

    if (showLoading && notifications.isEmpty) {
      isLoading = true;
    }

    error = null;

    notifyListeners();

    try {
      final loadedNotifications = await repository.getNotifications();

      loadedNotifications.sort(
        (first, second) => second.createdAtUtc.compareTo(first.createdAtUtc),
      );

      notifications = loadedNotifications;
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      isRefreshing = false;

      notifyListeners();
    }
  }

  Future<bool> markAsRead(int id) async {
    final index = notifications.indexWhere(
      (notification) => notification.id == id,
    );

    if (index == -1) {
      return false;
    }

    final currentNotification = notifications[index];

    if (currentNotification.isRead) {
      return true;
    }

    error = null;

    try {
      await repository.markAsRead(id);

      notifications[index] = NotificationModel(
        id: currentNotification.id,
        title: currentNotification.title,
        message: currentNotification.message,
        isRead: true,
        createdAtUtc: currentNotification.createdAtUtc,
      );

      notifyListeners();

      return true;
    } catch (exception) {
      error = exception.toString();

      notifyListeners();

      return false;
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(loadNotifications(showLoading: false));
    });
  }

  void _setConnectionStatus(NotificationConnectionStatus status) {
    connectionStatus = status;

    notifyListeners();
  }

  Future<void> stop() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;

    await realtimeService.stop();

    notifications = [];
    error = null;
    isLoading = false;
    isRefreshing = false;
    isInitialized = false;
    connectionStatus = NotificationConnectionStatus.disconnected;

    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();

    unawaited(realtimeService.stop());

    super.dispose();
  }
}
