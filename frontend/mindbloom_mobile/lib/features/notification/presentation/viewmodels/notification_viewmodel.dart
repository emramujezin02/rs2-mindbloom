import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/services/notification_realtime_service.dart';

class NotificationViewModel extends ChangeNotifier with WidgetsBindingObserver {
  static const int _pageSize = 20;
  final NotificationRepository repository;
  final Duration pollingInterval;
  late final NotificationRealtimeService realtimeService;

  NotificationViewModel({
    required this.repository,
    this.pollingInterval = const Duration(seconds: 60),
    required NotificationRealtimeService Function({
      required Future<void> Function() onNotificationReceived,
      required Future<void> Function() onReconnected,
      required void Function(NotificationConnectionStatus status)
      onConnectionStatusChanged,
    })
    realtimeServiceFactory,
  }) : assert(pollingInterval > Duration.zero) {
    realtimeService = realtimeServiceFactory(
      onNotificationReceived: refresh,
      onReconnected: refresh,
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
  bool _enabled = true;
  bool _foreground = true;
  bool _observing = false;
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
  Future<void> _tail = Future.value();
  Future<void>? _refreshFuture;
  final Map<int, Future<bool>> _readRequests = {};

  bool get hasMoreNotifications => _currentPage < _totalPages;
  bool get isRealtimeConnected =>
      connectionStatus == NotificationConnectionStatus.connected;
  String get connectionStatusText => switch (connectionStatus) {
    NotificationConnectionStatus.connected => 'Live',
    NotificationConnectionStatus.connecting => 'Connecting',
    NotificationConnectionStatus.reconnecting => 'Reconnecting',
    NotificationConnectionStatus.disconnected => 'Polling',
  };
  bool _current(int generation) =>
      !_isDisposed && _enabled && generation == _lifecycleGeneration;
  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  // List reads and read-state mutations share one queue. A response taken before
  // marking read cannot overwrite the later read state, nor can pages interleave.
  Future<void> _run(Future<void> Function(int generation) action) {
    final generation = _lifecycleGeneration;
    final operation = _tail.then((_) async {
      if (_current(generation) && _foreground) await action(generation);
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> initialize() async {
    if (_isDisposed || isInitialized || _isInitializing) return;
    _enabled = true;
    _isInitializing = true;
    final generation = _lifecycleGeneration;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    try {
      await loadFirstPage();
      if (!_current(generation)) return;
      isInitialized = true;
      _startPolling();
      if (_foreground) unawaited(_startRealtime(generation));
    } finally {
      if (_current(generation)) _isInitializing = false;
    }
  }

  Future<void> _startRealtime(int generation) async {
    if (!_current(generation) || !_foreground) return;
    try {
      await realtimeService.start();
    } catch (_) {
      // Durable REST polling remains available when realtime cannot start.
    }
  }

  Future<void> loadFirstPage({bool showLoading = true}) {
    if (_isDisposed || !_enabled || !_foreground) return Future.value();
    final active = _refreshFuture;
    if (active != null) return active;
    final generation = _lifecycleGeneration;
    isRefreshing = true;
    isLoading = showLoading && notifications.isEmpty;
    error = null;
    loadMoreError = null;
    final operation = _run((generation) async {
      try {
        // Refresh every already-loaded page so polling preserves pagination.
        final target = _currentPage < 1 ? 1 : _currentPage;
        final items = <int, NotificationModel>{};
        var lastPage = 0;
        var totalPages = 0;
        var unread = 0;
        for (var page = 1; page <= target; page++) {
          final response = await repository.getNotifications(
            pageNumber: page,
            pageSize: _pageSize,
          );
          if (!_current(generation) || !_foreground) return;
          for (final item in response.items) {
            items[item.id] = item;
          }
          lastPage = response.pageNumber;
          totalPages = response.totalPages;
          unread = response.unreadCount;
          if (page >= totalPages) break;
        }
        notifications = items.values.toList();
        _currentPage = lastPage;
        _totalPages = totalPages;
        unreadCount = unread;
        error = null;
      } catch (exception) {
        if (_current(generation)) error = AppErrorMessage.from(exception);
      }
    });
    late final Future<void> completed;
    completed = operation.whenComplete(() {
      if (_current(generation)) {
        isLoading = false;
        isRefreshing = false;
        notifyListeners();
      }
      if (identical(_refreshFuture, completed)) _refreshFuture = null;
    });
    _refreshFuture = completed;
    notifyListeners();
    return completed;
  }

  Future<void> refresh() => loadFirstPage(showLoading: false);

  Future<void> loadMore() async {
    if (_isDisposed ||
        !_enabled ||
        !_foreground ||
        isRefreshing ||
        isLoadingMore ||
        !hasMoreNotifications) {
      return;
    }
    final generation = _lifecycleGeneration;
    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();
    await _run((generation) async {
      try {
        final response = await repository.getNotifications(
          pageNumber: _currentPage + 1,
          pageSize: _pageSize,
        );
        if (!_current(generation) || !_foreground) return;
        notifications = {
          for (final item in [...notifications, ...response.items])
            item.id: item,
        }.values.toList();
        _currentPage = response.pageNumber;
        _totalPages = response.totalPages;
        unreadCount = response.unreadCount;
      } catch (exception) {
        if (_current(generation)) {
          loadMoreError = AppErrorMessage.from(exception);
        }
      }
    });
    if (_current(generation)) {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> retryLoadMore() => loadMore();

  Future<bool> markAsRead(int id) {
    final active = _readRequests[id];
    if (active != null) return active;
    final generation = _lifecycleGeneration;
    var success = false;
    late final Future<bool> result;
    result =
        _run((generation) async {
              final index = notifications.indexWhere((n) => n.id == id);
              if (index < 0) return;
              if (notifications[index].isRead) {
                success = true;
                return;
              }
              try {
                await repository.markAsRead(id);
                if (!_current(generation)) return;
                notifications = notifications
                    .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
                    .toList();
                if (unreadCount > 0) unreadCount--;
                error = null;
                success = true;
              } catch (exception) {
                if (_current(generation)) {
                  error = AppErrorMessage.from(exception);
                }
              }
            })
            .then((_) {
              if (_current(generation)) notifyListeners();
              return success;
            })
            .whenComplete(() {
              if (identical(_readRequests[id], result)) {
                _readRequests.remove(id);
              }
            });
    _readRequests[id] = result;
    return result;
  }

  Future<bool> markAllAsRead() async {
    if (_isDisposed || !_enabled) return false;
    if (isMarkingAllRead || unreadCount == 0) return true;
    final generation = _lifecycleGeneration;
    var success = false;
    isMarkingAllRead = true;
    notifyListeners();
    await _run((generation) async {
      try {
        await repository.markAllAsRead();
        if (!_current(generation)) return;
        notifications = notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        unreadCount = 0;
        error = null;
        success = true;
      } catch (exception) {
        if (_current(generation)) error = AppErrorMessage.from(exception);
      }
    });
    if (_current(generation)) {
      isMarkingAllRead = false;
      notifyListeners();
    }
    return success;
  }

  void clearError() {
    if (error != null) {
      error = null;
      notifyListeners();
    }
  }

  void clearLoadMoreError() {
    if (loadMoreError != null) {
      loadMoreError = null;
      notifyListeners();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    if (!_enabled || !_foreground || _isDisposed) return;
    _pollingTimer = Timer.periodic(pollingInterval, (_) {
      // A connected hub does not guarantee delivery from the separate Worker.
      if (!_enabled ||
          !_foreground ||
          isRefreshing ||
          isLoadingMore ||
          isMarkingAllRead ||
          _readRequests.isNotEmpty) {
        return;
      }
      unawaited(refresh());
    });
  }

  void _setConnectionStatus(NotificationConnectionStatus status) {
    if (!_isDisposed && _enabled && _foreground) {
      connectionStatus = status;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed || !_enabled) return;
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _pollingTimer?.cancel();
      unawaited(realtimeService.stop());
    } else if (isInitialized) {
      _startPolling();
      unawaited(refresh());
      unawaited(_startRealtime(_lifecycleGeneration));
    }
  }

  Future<void> stop() async {
    _enabled = false;
    _lifecycleGeneration++;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _refreshFuture = null;
    _readRequests.clear();
    notifications = [];
    unreadCount = 0;
    _currentPage = 0;
    _totalPages = 0;
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
    await realtimeService.stop();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _enabled = false;
    _lifecycleGeneration++;
    _pollingTimer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    unawaited(realtimeService.stop());
    super.dispose();
  }
}
