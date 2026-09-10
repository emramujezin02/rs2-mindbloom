import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/debug/mindbloom_debug_log.dart';
import '../../../../core/widgets/app_error_message.dart';
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
  bool _isInitializing = false;
  bool _isDisposed = false;
  int _lifecycleGeneration = 0;

  String? error;
  String? loadMoreError;

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
    if (isInitialized || _isInitializing) {
      logDebug(
        'MOBILE NOTIFICATIONS',
        'initialize skipped isInitialized=$isInitialized '
            'isInitializing=$_isInitializing',
      );

      return;
    }

    _isInitializing = true;
    final generation = _lifecycleGeneration;
    final stopwatch = Stopwatch()..start();

    logDebug(
      'MOBILE NOTIFICATIONS',
      'initialize started generation=$generation',
    );

    try {
      await loadFirstPage();

      if (_isDisposed || generation != _lifecycleGeneration) {
        return;
      }

      _startPolling();

      isInitialized = true;
      logDebug(
        'MOBILE NOTIFICATIONS',
        'initialize completed durationMs=${stopwatch.elapsedMilliseconds}',
      );

      unawaited(_startRealtime(generation));
    } finally {
      if (generation == _lifecycleGeneration) {
        _isInitializing = false;
      }

      logDebug(
        'MOBILE NOTIFICATIONS',
        'initialize finally isInitialized=$isInitialized '
            'isInitializing=$_isInitializing '
            'durationMs=${stopwatch.elapsedMilliseconds}',
      );
    }
  }

  Future<void> _startRealtime(int generation) async {
    final stopwatch = Stopwatch()..start();

    logDebug('MOBILE NOTIFICATIONS', 'realtime start requested');

    try {
      await realtimeService.start();
    } catch (error) {
      logDebug(
        'MOBILE NOTIFICATIONS',
        'realtime start failed ${error.runtimeType}: $error',
      );
    } finally {
      logDebug(
        'MOBILE NOTIFICATIONS',
        'realtime start finished '
            'stale=${generation != _lifecycleGeneration} '
            'durationMs=${stopwatch.elapsedMilliseconds}',
      );
    }
  }

  Future<void> loadFirstPage({bool showLoading = true}) async {
    if (isRefreshing) {
      logDebug('MOBILE NOTIFICATIONS', 'loadFirstPage skipped isRefreshing');

      return;
    }

    final generation = _lifecycleGeneration;
    final stopwatch = Stopwatch()..start();

    isRefreshing = true;

    if (showLoading && notifications.isEmpty) {
      isLoading = true;
    }

    error = null;
    loadMoreError = null;

    notifyListeners();
    logDebug(
      'MOBILE NOTIFICATIONS',
      'loadFirstPage started showLoading=$showLoading '
          'hasExistingItems=${notifications.isNotEmpty} generation=$generation',
    );

    try {
      final response = await repository.getNotifications(
        pageNumber: 1,
        pageSize: _pageSize,
      );

      if (_isDisposed || generation != _lifecycleGeneration) {
        return;
      }

      notifications = response.items;
      _currentPage = response.pageNumber;
      _totalPages = response.totalPages;
      unreadCount = response.unreadCount;

      error = null;
      logDebug(
        'MOBILE NOTIFICATIONS',
        'loadFirstPage success count=${notifications.length} '
            'unreadCount=$unreadCount durationMs=${stopwatch.elapsedMilliseconds}',
      );
    } catch (exception) {
      if (_isDisposed || generation != _lifecycleGeneration) {
        return;
      }

      error = AppErrorMessage.from(exception);
      logDebug(
        'MOBILE NOTIFICATIONS',
        'loadFirstPage failed ${exception.runtimeType}: $exception '
            'durationMs=${stopwatch.elapsedMilliseconds}',
      );
    } finally {
      if (!_isDisposed && generation == _lifecycleGeneration) {
        isLoading = false;
        isRefreshing = false;

        notifyListeners();
        logDebug(
          'MOBILE NOTIFICATIONS',
          'loadFirstPage finally isLoading=$isLoading '
              'isRefreshing=$isRefreshing errorPresent=${error != null}',
        );
      }
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
    loadMoreError = null;

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

      loadMoreError = null;
    } catch (exception) {
      loadMoreError = AppErrorMessage.from(exception);
    } finally {
      isLoadingMore = false;

      notifyListeners();
    }
  }

  Future<void> retryLoadMore() {
    return loadMore();
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
      error = AppErrorMessage.from(exception);

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
      error = null;

      return true;
    } catch (exception) {
      error = AppErrorMessage.from(exception);

      return false;
    } finally {
      isMarkingAllRead = false;

      notifyListeners();
    }
  }

  void clearError() {
    if (error == null) {
      return;
    }

    error = null;
    notifyListeners();
  }

  void clearLoadMoreError() {
    if (loadMoreError == null) {
      return;
    }

    loadMoreError = null;
    notifyListeners();
  }

  void _startPolling() {
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (isRealtimeConnected || isRefreshing) {
        return;
      }

      unawaited(refresh());
    });
  }

  void _setConnectionStatus(NotificationConnectionStatus status) {
    if (_isDisposed) {
      return;
    }

    connectionStatus = status;

    notifyListeners();
  }

  Future<void> stop() async {
    _lifecycleGeneration++;

    _pollingTimer?.cancel();
    _pollingTimer = null;

    await realtimeService.stop();

    notifications = [];
    unreadCount = 0;
    error = null;
    loadMoreError = null;
    isLoading = false;
    isRefreshing = false;
    isLoadingMore = false;
    isMarkingAllRead = false;
    isInitialized = false;
    _isInitializing = false;

    connectionStatus = NotificationConnectionStatus.disconnected;

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;

    _pollingTimer?.cancel();

    unawaited(realtimeService.stop());

    super.dispose();
  }
}
