import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/services/notification_realtime_service.dart';

class NotificationViewModel extends ChangeNotifier {
  static const int _pageSize = 20;

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
        await refresh();
      },
      onReconnected: () async {
        await refresh();
      },
      onConnectionStatusChanged: _setConnectionStatus,
    );
  }

  bool isLoading = false;
  bool isRefreshing = false;
  bool isLoadingMore = false;
  bool isMarkingAllRead = false;
  bool isInitialized = false;

  String? error;

  NotificationConnectionStatus connectionStatus =
      NotificationConnectionStatus.disconnected;

  List<NotificationModel> notifications = [];

  int unreadCount = 0;

  int _currentPage = 0;
  int _totalPages = 0;

  Timer? _pollingTimer;

  bool get hasMoreNotifications {
    return _currentPage < _totalPages;
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

    await loadFirstPage();

    await realtimeService.start();

    _startPolling();
  }

  Future<void> loadFirstPage({bool showLoading = true}) async {
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
      final response = await repository.getNotifications(
        pageNumber: 1,
        pageSize: _pageSize,
      );

      notifications = response.items;

      _currentPage = response.pageNumber;

      _totalPages = response.totalPages;

      unreadCount = response.unreadCount;
    } catch (exception) {
      error = _normalizeError(exception);
    } finally {
      isLoading = false;
      isRefreshing = false;

      notifyListeners();
    }
  }

  Future<void> refresh() {
    return loadFirstPage(showLoading: false);
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMoreNotifications) {
      return;
    }

    isLoadingMore = true;
    error = null;

    notifyListeners();

    try {
      final response = await repository.getNotifications(
        pageNumber: _currentPage + 1,
        pageSize: _pageSize,
      );

      final existingIds = notifications.map((item) => item.id).toSet();

      final newItems = response.items
          .where((item) => !existingIds.contains(item.id))
          .toList();

      notifications = [...notifications, ...newItems];

      _currentPage = response.pageNumber;

      _totalPages = response.totalPages;

      unreadCount = response.unreadCount;
    } catch (exception) {
      error = _normalizeError(exception);
    } finally {
      isLoadingMore = false;

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

    final current = notifications[index];

    if (current.isRead) {
      return true;
    }

    error = null;

    try {
      await repository.markAsRead(id);

      notifications[index] = current.copyWith(isRead: true);

      if (unreadCount > 0) {
        unreadCount--;
      }

      notifyListeners();

      return true;
    } catch (exception) {
      error = _normalizeError(exception);

      notifyListeners();

      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    if (isMarkingAllRead || unreadCount == 0) {
      return true;
    }

    isMarkingAllRead = true;
    error = null;

    notifyListeners();

    try {
      await repository.markAllAsRead();

      notifications = notifications
          .map((notification) => notification.copyWith(isRead: true))
          .toList();

      unreadCount = 0;

      return true;
    } catch (exception) {
      error = _normalizeError(exception);

      return false;
    } finally {
      isMarkingAllRead = false;

      notifyListeners();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refresh());
    });
  }

  void _setConnectionStatus(NotificationConnectionStatus status) {
    connectionStatus = status;

    notifyListeners();
  }

  String _normalizeError(Object exception) {
    final text = exception.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    return text;
  }

  Future<void> stop() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;

    await realtimeService.stop();

    notifications = [];
    unreadCount = 0;
    error = null;
    isLoading = false;
    isRefreshing = false;
    isLoadingMore = false;
    isMarkingAllRead = false;
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
