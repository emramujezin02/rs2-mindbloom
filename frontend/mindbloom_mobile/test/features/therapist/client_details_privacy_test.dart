import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/core/error/app_exception.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/core/widgets/app_error_message.dart';
import 'package:mindbloom_mobile/features/therapist/data/repositories/therapist_repository.dart';
import 'package:mindbloom_mobile/features/therapist/data/services/therapist_api_service.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/pages/therapist_client_details_page.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/viewmodels/therapist_client_details_viewmodel.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final status in [403, 404]) {
    for (final deniedSection in ['history', 'trend']) {
      test('Profile survives $deniedSection $status; all mood data is hidden', () async {
        final api = _Api();
        if (deniedSection == 'history') {
          api.history = (_) async => throw _failure(status);
        } else {
          api.trend = (_) async => throw _failure(status);
        }
        final vm = api.model();
        addTearDown(vm.dispose);
        await vm.loadClientDetails(101);
        expect(vm.client!.clientId, 101);
        expect(vm.errorMessage, isNull);
        expect(vm.moodHistory, isEmpty);
        expect(vm.moodTrend, isNull);
        expect(vm.moodHistoryMessage,
            TherapistClientDetailsViewModel.moodUnavailableMessage);
        expect(vm.moodTrendMessage, vm.moodHistoryMessage);
      });
    }

    test('Profile $status clears old profile and does not request mood', () async {
      final api = _Api();
      final vm = api.model();
      addTearDown(vm.dispose);
      await vm.loadClientDetails(101);
      api.calls.clear();
      api.details = (_) async => throw _failure(status);
      await vm.refresh();
      expect(vm.client, isNull);
      expect(vm.errorMessage, isNotNull);
      expect(vm.moodHistory, isEmpty);
      expect(vm.moodTrend, isNull);
      expect(api.calls, ['/Therapists/clients/101']);
    });
  }

  for (final section in ['history', 'trend']) {
    test('$section 500 is separate from privacy and preserves other section', () async {
      final api = _Api();
      if (section == 'history') {
        api.history = (_) async => throw _failure(500);
      } else {
        api.trend = (_) async => throw _failure(500);
      }
      final vm = api.model();
      addTearDown(vm.dispose);
      await vm.loadClientDetails(101);
      expect(vm.client, isNotNull);
      expect(vm.errorMessage, isNull);
      if (section == 'history') {
        expect(vm.moodHistory, isEmpty);
        expect(vm.moodHistoryMessage, AppErrorMessage.serverUnavailable);
        expect(vm.moodTrend, isNotNull);
        expect(vm.moodTrendMessage, isNull);
      } else {
        expect(vm.moodTrend, isNull);
        expect(vm.moodTrendMessage, AppErrorMessage.serverUnavailable);
        expect(vm.moodHistory, hasLength(1));
        expect(vm.moodHistoryMessage, isNull);
      }
    });
  }

  for (final error in [
    TimeoutException('timeout'),
    const AppException(message: 'No internet connection'),
  ]) {
    test('Technical mood failure is not an empty or privacy result: $error', () async {
      final api = _Api()..history = (_) async => throw error;
      final vm = api.model();
      addTearDown(vm.dispose);
      await vm.loadClientDetails(101);
      expect(vm.client, isNotNull);
      expect(vm.errorMessage, isNull);
      expect(vm.moodHistory, isEmpty);
      expect(vm.moodHistoryMessage, AppErrorMessage.from(error));
      expect(vm.moodHistoryMessage,
          isNot(TherapistClientDetailsViewModel.moodUnavailableMessage));
    });
  }

  test('Successful empty mood response has no access or technical error', () async {
    final api = _Api();
    api.history = (_) async => {'items': []};
    api.trend = (id) async => _trend(id, empty: true);
    final vm = api.model();
    addTearDown(vm.dispose);
    await vm.loadClientDetails(101);
    expect(vm.client, isNotNull);
    expect(vm.moodHistory, isEmpty);
    expect(vm.moodTrend!.hasData, isFalse);
    expect(vm.moodHistoryMessage, isNull);
    expect(vm.moodTrendMessage, isNull);
  });

  test('Allowed full profile still loads both mood sections', () async {
    final api = _Api();
    final vm = api.model();
    addTearDown(vm.dispose);
    await vm.loadClientDetails(101);
    expect(vm.client!.fullName, 'Client 101');
    expect(vm.moodHistory.single.emotion, 'F2 private emotion');
    expect(vm.moodTrend!.clientId, 101);
    expect(vm.moodHistoryMessage, isNull);
    expect(vm.moodTrendMessage, isNull);
    expect(vm.isLoading, isFalse);
    expect(vm.isLoadingMood, isFalse);
    expect(api.calls, [
      '/Therapists/clients/101',
      '/JournalEntries/clients/101/history',
      '/JournalEntries/clients/101/trend',
    ]);
  });

  test('Refresh immediately clears mood and respects withdrawn consent', () async {
    final api = _Api();
    final vm = api.model();
    addTearDown(vm.dispose);
    await vm.loadClientDetails(101);
    final hold = Completer<dynamic>();
    api.details = (_) => hold.future;
    api.history = (_) async => throw _failure(404);
    final refresh = vm.refresh();
    expect(vm.client, isNull);
    expect(vm.moodHistory, isEmpty);
    expect(vm.moodTrend, isNull);
    hold.complete(_profile(101));
    await refresh;
    expect(vm.client!.clientId, 101);
    expect(vm.moodHistory, isEmpty);
    expect(vm.moodTrend, isNull);
  });

  test('Late old client mood results cannot overwrite the new client', () async {
    final api = _Api();
    final history = Completer<dynamic>();
    final trend = Completer<dynamic>();
    api.history = (id) async => id == 101 ? await history.future : _history();
    api.trend = (id) async => id == 101 ? await trend.future : _trend(id);
    final vm = api.model();
    addTearDown(vm.dispose);
    final first = vm.loadClientDetails(101);
    await Future<void>.delayed(Duration.zero);
    expect(vm.client!.clientId, 101);
    await vm.loadClientDetails(202);
    history.completeError(_failure(404));
    trend.complete(_trend(101));
    await first;
    expect(vm.client!.clientId, 202);
    expect(vm.moodTrend!.clientId, 202);
    expect(vm.moodHistoryMessage, isNull);
    expect(vm.moodTrendMessage, isNull);
  });

  test('Technical errors on refresh do not retain earlier mood data', () async {
    final api = _Api();
    final vm = api.model();
    addTearDown(vm.dispose);
    await vm.loadClientDetails(101);
    expect(vm.moodHistory, isNotEmpty);
    expect(vm.moodTrend, isNotNull);
    api.history = (_) async => throw _failure(500);
    api.trend = (_) async => throw TimeoutException('timeout');
    await vm.refresh();
    expect(vm.client, isNotNull);
    expect(vm.moodHistory, isEmpty);
    expect(vm.moodTrend, isNull);
    expect(vm.moodHistoryMessage, AppErrorMessage.serverUnavailable);
    expect(vm.moodTrendMessage, AppErrorMessage.timeout);
  });

  test('Late success cannot restore mood after the other endpoint denies access', () async {
    final api = _Api();
    final trend = Completer<dynamic>();
    api.history = (_) async => throw _failure(404);
    api.trend = (_) => trend.future;
    final vm = api.model();
    addTearDown(vm.dispose);
    final load = vm.loadClientDetails(101);
    await Future<void>.delayed(Duration.zero);
    trend.complete(_trend(101));
    await load;
    expect(vm.client, isNotNull);
    expect(vm.moodHistory, isEmpty);
    expect(vm.moodTrend, isNull);
  });

  test('Late old profile cannot replace a new basicOnly profile', () async {
    final api = _Api();
    final hold = Completer<dynamic>();
    api.details = (_) => hold.future;
    final vm = api.model();
    addTearDown(vm.dispose);
    final old = vm.loadClientDetails(101);
    await vm.loadClientDetails(202, basicOnly: true);
    hold.complete(_profile(101));
    await old;
    expect(vm.client!.clientId, 202);
    expect(api.calls.where((path) => path.startsWith('/JournalEntries')), isEmpty);
    await vm.refresh();
    expect(api.calls.last, '/Therapists/clients/202/profile');
  });

  test('Dispose during mood loading does not publish late state', () async {
    final api = _Api();
    final history = Completer<dynamic>();
    api.history = (_) => history.future;
    final vm = api.model();
    var notifications = 0;
    vm.addListener(() => notifications++);
    final load = vm.loadClientDetails(101);
    await Future<void>.delayed(Duration.zero);
    final beforeDispose = notifications;
    vm.dispose();
    history.complete(_history());
    await load;
    expect(notifications, beforeDispose);
    expect(vm.moodHistory, isEmpty);
  });

  for (final status in [403, 404, 500]) {
    testWidgets('Full profile remains visible with mood HTTP $status', (tester) async {
      final api = _Api();
      api.history = (_) async => throw _failure(status);
      api.trend = (_) async => throw _failure(status);
      await tester.pumpWidget(MaterialApp(home: TherapistClientDetailsPage(
        clientId: 101, viewModel: api.model(),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Client 101'), findsOneWidget);
      expect(find.text('Client details could not be loaded'), findsNothing);
      expect(find.text('F2 private emotion'), findsNothing);
      expect(find.textContaining(status == 500
          ? AppErrorMessage.serverUnavailable
          : TherapistClientDetailsViewModel.moodUnavailableMessage), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Profile is visible while optional mood requests are still loading', (tester) async {
    final hold = Completer<dynamic>();
    final api = _Api()..history = (_) => hold.future;
    await tester.pumpWidget(MaterialApp(home: TherapistClientDetailsPage(
      clientId: 101, viewModel: api.model(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Client 101'), findsOneWidget);
    expect(find.text('Loading mood data...'), findsOneWidget);
    hold.complete(_history());
    await tester.pumpAndSettle();
    expect(find.text('Loading mood data...'), findsNothing);
    expect(find.text('F2 private emotion'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final status in [403, 404]) {
    testWidgets('Denied profile $status never displays client or mood', (tester) async {
      final api = _Api()..details = (_) async => throw _failure(status);
      await tester.pumpWidget(MaterialApp(home: TherapistClientDetailsPage(
        clientId: 101, viewModel: api.model(),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Client 101'), findsNothing);
      expect(find.text('Client details could not be loaded'), findsOneWidget);
      expect(find.text('F2 private emotion'), findsNothing);
      expect(api.calls, ['/Therapists/clients/101']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Successful empty response displays the existing empty mood state', (tester) async {
    final api = _Api();
    api.history = (_) async => {'items': []};
    api.trend = (id) async => _trend(id, empty: true);
    await tester.pumpWidget(MaterialApp(home: TherapistClientDetailsPage(
      clientId: 101, viewModel: api.model(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Client 101'), findsOneWidget);
    expect(find.text('No emotional tracker entries'), findsOneWidget);
    expect(find.textContaining('Mood history:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reused page clears old client and reloads the new client', (tester) async {
    final api = _Api();
    final vm = api.model();
    await tester.pumpWidget(MaterialApp(home: TherapistClientDetailsPage(
      clientId: 101, viewModel: vm,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Client 101'), findsOneWidget);
    api.history = (_) async => throw _failure(404);
    await tester.pumpWidget(MaterialApp(home: TherapistClientDetailsPage(
      clientId: 202, viewModel: vm,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Client 101'), findsNothing);
    expect(find.text('Client 202'), findsOneWidget);
    expect(find.text('F2 private emotion'), findsNothing);
    expect(vm.moodTrend, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('basicOnly displays only restricted profile and calls no mood API', (tester) async {
    final api = _Api();
    await tester.pumpWidget(MaterialApp(home: TherapistClientDetailsPage(
      clientId: 101, basicOnly: true, viewModel: api.model(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Client 101'), findsOneWidget);
    expect(find.text('Emotional Tracker'), findsNothing);
    expect(find.text('Appointment History'), findsNothing);
    expect(api.calls, ['/Therapists/clients/101/profile']);
    expect(tester.takeException(), isNull);
  });
}

AppException _failure(int status) =>
    AppException(message: 'Test response $status', statusCode: status);

Map<String, dynamic> _profile(int id) => {
  'clientId': id, 'fullName': 'Client $id', 'email': 'client@test.local',
};

Map<String, dynamic> _history() => {
  'items': [
    {'id': 1, 'createdAtUtc': '2026-10-29T10:00:00Z',
      'mood': 4, 'emotion': 'F2 private emotion'},
  ],
};

Map<String, dynamic> _trend(int id, {bool empty = false}) => {
  'clientId': id, 'days': 30, 'totalEntries': empty ? 0 : 1,
  'averageMood': empty ? null : 4.0, 'trend': 'InsufficientData',
  'points': [], 'emotions': [],
};

// Same fake ApiClient pattern as therapist_daily_overview_test.dart.
// All reads are handled here; no HTTP, session storage or external services run.
class _Api extends ApiClient {
  _Api() : super(sessionStorage: SessionStorageService());
  final calls = <String>[];
  Future<dynamic> Function(int) details = (id) async => _profile(id);
  Future<dynamic> Function(int) history = (_) async => _history();
  Future<dynamic> Function(int) trend = (id) async => _trend(id);

  TherapistClientDetailsViewModel model() => TherapistClientDetailsViewModel(
    repository: TherapistRepository(
      therapistApiService: TherapistApiService(apiClient: this),
    ),
  );

  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    calls.add(endpoint);
    final parts = Uri.parse(endpoint).pathSegments;
    final id = int.parse(parts[2]);
    if (parts[0] == 'Therapists') {
      return parts.length == 4 ? _profile(id) : details(id);
    }
    if (parts[0] == 'JournalEntries') {
      if (parts.last == 'history') return history(id);
      if (parts.last == 'trend') return trend(id);
    }
    throw StateError('Unexpected test endpoint: $endpoint');
  }
}
