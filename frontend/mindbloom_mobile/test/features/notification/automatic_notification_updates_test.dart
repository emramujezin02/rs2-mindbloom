import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/features/notification/data/repositories/notification_repository.dart';
import 'package:mindbloom_mobile/features/notification/data/services/notification_api_service.dart';
import 'package:mindbloom_mobile/features/notification/data/services/notification_realtime_service.dart';
import 'package:mindbloom_mobile/features/notification/presentation/pages/notification_page.dart';
import 'package:mindbloom_mobile/features/notification/presentation/viewmodels/notification_scope.dart';
import 'package:mindbloom_mobile/features/notification/presentation/viewmodels/notification_viewmodel.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  test(
    'Real realtime service cannot start a stale connection after logout',
    () async {
      final storage = _DelayedStorage();
      final statuses = <NotificationConnectionStatus>[];
      final service = NotificationRealtimeService(
        sessionStorage: storage,
        onNotificationReceived: () async {},
        onReconnected: () async {},
        onConnectionStatusChanged: statuses.add,
      );
      final starting = service.start();
      await service.stop();
      storage.token.complete('synthetic-old-session');
      await starting;
      expect(statuses, [NotificationConnectionStatus.disconnected]);
      expect(service.isConnected, isFalse);
    },
  );
  test(
    'Missing token does not leave realtime startup permanently busy',
    () async {
      final storage = _EmptyStorage();
      final service = NotificationRealtimeService(
        sessionStorage: storage,
        onNotificationReceived: () async {},
        onReconnected: () async {},
        onConnectionStatusChanged: (_) {},
      );
      await service.start();
      await service.start();
      await service.stop();
      expect(storage.reads, 2);
      expect(service.isConnected, isFalse);
    },
  );
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
  }

  for (final connected in [true, false]) {
    testWidgets(
      'Automatic poll discovers Worker data while connected=$connected',
      (tester) async {
        final api = _Api();
        final vm = api.model(connected: connected);
        unawaited(vm.initialize());
        await flush(tester);
        expect(vm.isRealtimeConnected, connected);
        api.items.add(item(1));
        await tester.pump(const Duration(seconds: 60));
        await flush(tester);
        expect(vm.notifications.single.id, 1);
        expect(vm.unreadCount, 1);
        expect(api.gets, 2);
        vm.dispose();
      },
    );
  }
  testWidgets('Configured interval is respected without aggressive polling', (
    tester,
  ) async {
    final api = _Api();
    final vm = api.model(interval: const Duration(seconds: 90));
    unawaited(vm.initialize());
    await flush(tester);
    await tester.pump(const Duration(seconds: 89));
    await flush(tester);
    expect(api.gets, 1);
    await tester.pump(const Duration(seconds: 1));
    await flush(tester);
    expect(api.gets, 2);
    vm.dispose();
  });
  testWidgets('Mark all read is serialized and remains read after polling', (
    tester,
  ) async {
    final api = _Api()..items = [item(2), item(1)];
    final vm = api.model();
    unawaited(vm.initialize());
    await flush(tester);
    unawaited(vm.markAllAsRead());
    await flush(tester);
    await tester.pump(const Duration(seconds: 60));
    await flush(tester);
    expect(vm.unreadCount, 0);
    expect(vm.notifications.every((n) => n.isRead), isTrue);
    expect(api.puts, 1);
    vm.dispose();
  });
  testWidgets(
    'Slow requests coalesce poll, manual refresh and duplicate events',
    (tester) async {
      final api = _Api();
      final vm = api.model();
      unawaited(vm.initialize());
      await flush(tester);
      api.items.add(item(1));
      api.block = Completer<void>();
      unawaited(vm.refresh());
      await flush(tester);
      unawaited(vm.refresh());
      unawaited(api.realtime.onNotificationReceived());
      await tester.pump(const Duration(minutes: 3));
      await flush(tester);
      expect(api.gets, 2);
      expect(api.maxConcurrent, 1);
      api.block!.complete();
      await flush(tester);
      expect(vm.notifications.length, 1);
      vm.dispose();
    },
  );
  testWidgets('Temporary API failure recovers at next poll', (tester) async {
    final api = _Api();
    final vm = api.model();
    unawaited(vm.initialize());
    await flush(tester);
    api.fail = true;
    await tester.pump(const Duration(seconds: 60));
    await flush(tester);
    expect(vm.error, isNotNull);
    api.fail = false;
    api.items.addAll([item(2), item(1)]);
    await tester.pump(const Duration(seconds: 60));
    await flush(tester);
    expect(vm.notifications.map((n) => n.id), [2, 1]);
    expect(vm.unreadCount, 2);
    expect(vm.error, isNull);
    vm.dispose();
  });
  testWidgets('ReceiveNotification and reconnect refresh without duplicates', (
    tester,
  ) async {
    final api = _Api();
    final vm = api.model();
    unawaited(vm.initialize());
    await flush(tester);
    api.items.add(item(1));
    unawaited(api.realtime.onNotificationReceived());
    unawaited(api.realtime.onNotificationReceived());
    await flush(tester);
    expect(vm.notifications.length, 1);
    expect(api.gets, 2);
    api.items.insert(0, item(2));
    unawaited(api.realtime.onReconnected());
    await flush(tester);
    expect(vm.notifications.length, 2);
    expect(vm.unreadCount, 2);
    vm.dispose();
  });
  testWidgets('Background pauses polling; resume refreshes and restarts once', (
    tester,
  ) async {
    final api = _Api();
    final vm = api.model();
    unawaited(vm.initialize());
    await flush(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    await flush(tester);
    expect(api.gets, 1);
    api.items.add(item(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flush(tester);
    expect(vm.notifications.length, 1);
    await tester.pump(const Duration(seconds: 60));
    await flush(tester);
    expect(api.gets, 3);
    vm.dispose();
  });
  testWidgets('Logout clears immediately and ignores late reads and events', (
    tester,
  ) async {
    final api = _Api();
    final vm = api.model();
    unawaited(vm.initialize());
    await flush(tester);
    api.block = Completer<void>();
    unawaited(vm.refresh());
    await flush(tester);
    await vm.stop();
    api.items.add(item(1));
    api.block!.complete();
    await flush(tester);
    unawaited(api.realtime.onNotificationReceived());
    await tester.pump(const Duration(minutes: 3));
    await flush(tester);
    expect(vm.notifications, isEmpty);
    expect(vm.unreadCount, 0);
    expect(api.gets, 2);
    api.items = [item(20)];
    api.block = null;
    unawaited(vm.initialize());
    await flush(tester);
    expect(vm.notifications.single.id, 20);
    vm.dispose();
  });
  testWidgets('Dispose stops timer and prevents late notifications', (
    tester,
  ) async {
    final api = _Api();
    final vm = api.model();
    var changes = 0;
    vm.addListener(() => changes++);
    unawaited(vm.initialize());
    await flush(tester);
    api.block = Completer<void>();
    unawaited(vm.refresh());
    await flush(tester);
    vm.dispose();
    final before = changes;
    api.block!.complete();
    await tester.pump(const Duration(minutes: 2));
    await flush(tester);
    expect(changes, before);
    expect(api.gets, 2);
  });
  testWidgets('Repeated initialize creates one polling loop', (tester) async {
    final api = _Api();
    final vm = api.model();
    unawaited(vm.initialize());
    unawaited(vm.initialize());
    await flush(tester);
    unawaited(vm.initialize());
    await tester.pump(const Duration(seconds: 60));
    await flush(tester);
    expect(api.gets, 2);
    expect(api.realtime.starts, 1);
    vm.dispose();
  });
  testWidgets('Polling preserves loaded pages and server order', (
    tester,
  ) async {
    final api = _Api()..items = [for (var i = 25; i > 0; i--) item(i)];
    final vm = api.model();
    unawaited(vm.initialize());
    await flush(tester);
    unawaited(vm.loadMore());
    await flush(tester);
    expect(vm.notifications.length, 25);
    api.items.insert(0, item(26));
    await tester.pump(const Duration(seconds: 60));
    await flush(tester);
    expect(vm.notifications.length, 26);
    expect(vm.notifications.first.id, 26);
    expect(vm.notifications.map((n) => n.id).toSet().length, 26);
    expect(api.maxConcurrent, 1);
    vm.dispose();
  });
  testWidgets('Read mutation waits for refresh and cannot revert read state', (
    tester,
  ) async {
    final api = _Api()..items = [item(1)];
    final vm = api.model();
    unawaited(vm.initialize());
    await flush(tester);
    api.block = Completer<void>();
    unawaited(vm.refresh());
    await flush(tester);
    unawaited(vm.markAsRead(1));
    await flush(tester);
    expect(api.puts, 0);
    api.block!.complete();
    await flush(tester);
    expect(vm.notifications.single.isRead, isTrue);
    expect(vm.unreadCount, 0);
    await tester.pump(const Duration(seconds: 60));
    await flush(tester);
    expect(vm.notifications.single.isRead, isTrue);
    expect(api.puts, 1);
    vm.dispose();
  });
  testWidgets('Open notification UI and badge update without user action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _Api();
    final vm = api.model();
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScope(
          notificationViewModel: vm,
          child: Builder(
            builder: (context) => Column(
              children: [
                Text('Badge: ${NotificationScope.of(context).unreadCount}'),
                const Expanded(child: NotificationPage()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    api.items.add(item(1));
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    expect(find.text('New appointment request'), findsOneWidget);
    expect(find.text('Badge: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
  const path = String.fromEnvironment('TASK18_NOTIFICATION_FIXTURE');
  testWidgets(
    'Actual Worker SQL/API payload appears in open Flutter UI on automatic poll',
    (tester) async {
      final fixture =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      var persisted = false;
      var gets = 0;
      final client = MockClient((request) async {
        expect(
          request.headers['authorization'],
          'Bearer synthetic-mobile-session',
        );
        expect(request.url.path.endsWith('/Notifications'), isTrue);
        gets++;
        return http.Response(
          jsonEncode(fixture[persisted ? 'after' : 'before']),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiClient(sessionStorage: _Storage(), httpClient: client);
      late _Realtime realtime;
      final vm = NotificationViewModel(
        repository: NotificationRepository(
          apiService: NotificationApiService(apiClient: api),
        ),
        realtimeServiceFactory:
            ({
              required onNotificationReceived,
              required onReconnected,
              required onConnectionStatusChanged,
            }) => realtime = _Realtime(
              onNotificationReceived: onNotificationReceived,
              onReconnected: onReconnected,
              onConnectionStatusChanged: onConnectionStatusChanged,
            ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationScope(
            notificationViewModel: vm,
            child: const NotificationPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(vm.notifications, isEmpty);
      expect(realtime.starts, 1);
      persisted = true;
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(find.text('New appointment request'), findsOneWidget);
      expect(vm.unreadCount, 1);
      expect(gets, 2);
      expect((fixture['otherUser'] as Map)['items'], isEmpty);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      client.close();
    },
    skip: path.isEmpty,
  );
}

Map<String, dynamic> item(int id) => {
  'id': id,
  'title': 'New appointment request',
  'message': 'You have received a new appointment request.',
  'isRead': false,
  'createdAtUtc': '2026-10-29T12:00:00Z',
  'actionType': 'Appointment',
  'appointmentId': 100,
};

class _Storage extends SessionStorageService {
  @override
  Future<String?> getToken() async => 'synthetic-mobile-session';
}

class _Api extends ApiClient {
  _Api() : super(sessionStorage: _Storage());
  List<Map<String, dynamic>> items = [];
  bool fail = false;
  Completer<void>? block;
  int gets = 0, puts = 0, concurrent = 0, maxConcurrent = 0;
  late _Realtime realtime;
  NotificationViewModel model({
    bool connected = true,
    Duration interval = const Duration(seconds: 60),
  }) => NotificationViewModel(
    pollingInterval: interval,
    repository: NotificationRepository(
      apiService: NotificationApiService(apiClient: this),
    ),
    realtimeServiceFactory:
        ({
          required onNotificationReceived,
          required onReconnected,
          required onConnectionStatusChanged,
        }) => realtime = _Realtime(
          connected: connected,
          onNotificationReceived: onNotificationReceived,
          onReconnected: onReconnected,
          onConnectionStatusChanged: onConnectionStatusChanged,
        ),
  );
  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    gets++;
    concurrent++;
    if (concurrent > maxConcurrent) maxConcurrent = concurrent;
    try {
      final snapshot = items.map((i) => Map<String, dynamic>.from(i)).toList();
      if (block != null) await block!.future;
      if (fail) throw Exception('Temporary network failure');
      final uri = Uri.parse(endpoint);
      final page = int.parse(uri.queryParameters['pageNumber']!);
      return {
        'items': snapshot.skip((page - 1) * 20).take(20).toList(),
        'pageNumber': page,
        'pageSize': 20,
        'totalCount': snapshot.length,
        'totalPages': (snapshot.length / 20).ceil(),
        'unreadCount': snapshot.where((n) => n['isRead'] == false).length,
      };
    } finally {
      concurrent--;
    }
  }

  @override
  Future<dynamic> put(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    puts++;
    for (final i in items) {
      if (endpoint.endsWith('/read-all') ||
          endpoint.contains('/${i['id']}/read')) {
        i['isRead'] = true;
      }
    }
    return null;
  }
}

class _Realtime extends NotificationRealtimeService {
  final bool connected;
  int starts = 0;
  _Realtime({
    this.connected = true,
    required super.onNotificationReceived,
    required super.onReconnected,
    required super.onConnectionStatusChanged,
  }) : super(sessionStorage: _Storage());
  @override
  Future<void> start() async {
    starts++;
    onConnectionStatusChanged(
      connected
          ? NotificationConnectionStatus.connected
          : NotificationConnectionStatus.disconnected,
    );
  }

  @override
  Future<void> stop() async {
    onConnectionStatusChanged(NotificationConnectionStatus.disconnected);
  }
}

class _DelayedStorage extends SessionStorageService {
  final token = Completer<String?>();
  @override
  Future<String?> getToken() => token.future;
}

class _EmptyStorage extends SessionStorageService {
  int reads = 0;
  @override
  Future<String?> getToken() async {
    reads++;
    return null;
  }
}
