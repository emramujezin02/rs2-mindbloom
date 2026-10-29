import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/core/time/appointment_time_zone.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';
import 'package:mindbloom_mobile/features/appointment/data/repositories/appointment_repository.dart';
import 'package:mindbloom_mobile/features/appointment/data/services/appointment_api_service.dart';
import 'package:mindbloom_mobile/features/appointment/data/models/therapist_appointment_status.dart';
import 'package:mindbloom_mobile/features/appointment/presentation/pages/therapist_appointments_page.dart';
import 'package:mindbloom_mobile/features/appointment/presentation/viewmodels/therapist_appointments_viewmodel.dart';
import 'package:mindbloom_mobile/features/appointment/presentation/widgets/booking_calendar.dart';
import 'package:mindbloom_mobile/features/therapist/data/repositories/therapist_repository.dart';
import 'package:mindbloom_mobile/features/therapist/data/services/therapist_api_service.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/pages/therapist_client_details_page.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/viewmodels/therapist_client_details_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final empty in [true, false]) {
    test(
      empty
          ? 'Nonworking day has no invented slots'
          : 'Working interval break is not offered',
      () async {
        final api = _Api()
          ..emptySchedule = empty
          ..breakSchedule = !empty;
        final vm = api.model();
        await vm.loadAppointments();
        expect(vm.freeSlots, isEmpty);
        expect(vm.occupiedAppointments.length, 2);
        vm.dispose();
      },
    );
  }
  test(
    'All appointment pages block slots; cancelled and rejected do not',
    () async {
      final api = _Api();
      final vm = api.model();
      await vm.loadAppointments();
      expect(vm.appointments.length, 4);
      expect(vm.occupiedAppointments.length, 2);
      expect(vm.freeSlots.map((s) => s.start.hour), [10]);
      final queries = api.calls
          .map(Uri.parse)
          .where((u) => u.path == '/Appointments/therapist');
      expect(queries.length, 2);
      expect(
        queries.every((u) => u.queryParameters['overlapsRange'] == 'true'),
        isTrue,
      );
      expect(
        queries.every((u) => !u.queryParameters.containsKey('status')),
        isTrue,
      );
      final calls = api.calls.length;
      await vm.selectStatusFilter(TherapistAppointmentStatus.cancelled);
      expect(vm.appointments.single.status, 'Cancelled');
      expect(vm.freeSlots.single.start.hour, 10);
      expect(api.calls.length, calls);
      vm.dispose();
    },
  );
  test('Absences on later pages remove slots', () async {
    final api = _Api()..absence = true;
    final vm = api.model();
    await vm.loadAppointments();
    expect(vm.freeSlots, isEmpty);
    expect(api.calls.where((s) => s.contains('unavailable-dates')).length, 2);
    vm.dispose();
  });
  test(
    'Historical completed sessions visible without invented free history',
    () async {
      final api = _Api()..completed = true;
      final vm = api.model();
      await vm.selectCustomDate(DateTime.utc(2025, 1, 1));
      expect(vm.isHistoricalDay, isTrue);
      expect(vm.freeSlots, isEmpty);
      expect(vm.otherAppointments.any((a) => a.status == 'Completed'), isTrue);
      vm.dispose();
    },
  );
  test('Status update refreshes day and frees rejected slot', () async {
    final api = _Api();
    final vm = api.model();
    await vm.loadAppointments();
    final day = vm.day;
    await vm.updateStatus(
      appointment: vm.appointments.firstWhere((a) => a.id == 1),
      status: TherapistAppointmentStatus.rejected,
      reason: 'Valid reason',
    );
    expect(api.puts, 1);
    expect(api.reason, 'Valid reason');
    expect(vm.day, day);
    expect(vm.freeSlots.map((s) => s.start.hour), [9, 10]);
    vm.dispose();
  });
  test('Late response cannot overwrite newer date; disposal safe', () async {
    final api = _Api()..hold = Completer<dynamic>();
    final vm = api.model();
    final first = vm.loadAppointments();
    await Future<void>.delayed(Duration.zero);
    await vm.selectCustomDate(DateTime.utc(2026, 10, 30));
    api.hold!.complete(_page([], 1, 1));
    await first;
    expect(vm.day, DateTime.utc(2026, 10, 30));
    expect(vm.appointments.length, 4);
    vm.dispose();
    expect(() => vm.notifyListeners(), returnsNormally);
  });
  for (final (month, day, hours) in [(3, 29, 23), (10, 25, 25)]) {
    test('Sarajevo day $month/$day spans $hours UTC hours', () {
      final (start, end) = AppointmentTimeZone.dayBounds(
        DateTime.utc(2026, month, day),
      );
      expect(end.difference(start).inHours, hours);
      expect(start.isUtc, isTrue);
      expect(AppointmentTimeZone.fromInstant(start).hour, 0);
    });
  }
  test(
    'Basic profile requests only restricted endpoint and no mood or finances',
    () async {
      final api = _Api();
      final vm = TherapistClientDetailsViewModel(repository: api.therapists);
      await vm.loadClientDetails(101, basicOnly: true);
      expect(vm.client!.fullName, 'Client Example');
      expect(vm.moodHistory, isEmpty);
      expect(vm.moodTrend, isNull);
      expect(api.calls, ['/Therapists/clients/101/profile']);
      await vm.refresh();
      expect(api.calls.last, '/Therapists/clients/101/profile');
      vm.dispose();
    },
  );
  test('Unavailable profile fails closed', () async {
    final api = _Api()..fail = true;
    final vm = TherapistClientDetailsViewModel(repository: api.therapists);
    await vm.loadClientDetails(101, basicOnly: true);
    expect(vm.client, isNull);
    expect(vm.errorMessage, isNotNull);
    expect(api.calls.length, 1);
    vm.dispose();
  });
  for (final width in [320.0, 800.0]) {
    testWidgets('Calendar and daily groups fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, width == 320 ? 640 : 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Api();
      final vm = api.model();
      await tester.pumpWidget(
        MaterialApp(home: TherapistAppointmentsPage(viewModel: vm)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookingCalendar), findsOneWidget);
      final count = api.calls.length;
      await tester.tap(find.byKey(const Key('next-month')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('previous-month')));
      await tester.pumpAndSettle();
      expect(api.calls.length, count);
      expect(
        find.byKey(const Key('daily-columns')),
        width >= 640 ? findsOneWidget : findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('daily-occupied')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Historical dates and year navigation preserve selected day', (
    tester,
  ) async {
    final api = _Api();
    final vm = api.model();
    await tester.pumpWidget(
      MaterialApp(home: TherapistAppointmentsPage(viewModel: vm)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day-2026-10-28')));
    await tester.pumpAndSettle();
    expect(vm.day, DateTime.utc(2026, 10, 28));
    expect(vm.freeSlots, isEmpty);
    await tester.tap(find.byKey(const Key('day-2026-10-30')));
    await tester.pumpAndSettle();
    expect(vm.day, DateTime.utc(2026, 10, 30));
    final calls = api.calls.length;
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('next-month')));
      await tester.pumpAndSettle();
    }
    expect(find.text('January 2027'), findsOneWidget);
    expect(api.calls.length, calls);
    expect(vm.day, DateTime.utc(2026, 10, 30));
  });
  testWidgets('Load failure has no stale slots and retry succeeds', (
    tester,
  ) async {
    final api = _Api()..fail = true;
    final vm = api.model();
    await tester.pumpWidget(
      MaterialApp(home: TherapistAppointmentsPage(viewModel: vm)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profile unavailable'), findsOneWidget);
    expect(vm.freeSlots, isEmpty);
    api.fail = false;
    await vm.loadAppointments();
    await tester.pumpAndSettle();
    expect(vm.appointments.length, 4);
    expect(find.text('Profile unavailable'), findsNothing);
  });
  testWidgets('Leaving during a slow load is safe', (tester) async {
    final api = _Api()..hold = Completer<dynamic>();
    final vm = api.model();
    await tester.pumpWidget(
      MaterialApp(home: TherapistAppointmentsPage(viewModel: vm)),
    );
    await tester.pump();
    await tester.pump();
    expect(vm.isLoading, isTrue);
    await tester.pumpWidget(const SizedBox());
    api.hold!.complete(_page([], 1, 1));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Client click opens basic profile; return preserves date and sends no mutation',
    (tester) async {
      final api = _Api();
      final vm = api.model();
      Object? arguments;
      await tester.pumpWidget(
        MaterialApp(
          home: TherapistAppointmentsPage(viewModel: vm),
          onGenerateRoute: (settings) {
            arguments = settings.arguments;
            final args = arguments! as TherapistClientDetailsArguments;
            return MaterialPageRoute<void>(
              builder: (_) => TherapistClientDetailsPage(
                clientId: args.clientId,
                basicOnly: args.basicOnly,
                viewModel: TherapistClientDetailsViewModel(
                  repository: api.therapists,
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      final day = vm.day;
      await tester.scrollUntilVisible(
        find.byKey(const Key('client-profile-3')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('client-profile-3')));
      await tester.pumpAndSettle();
      expect((arguments! as TherapistClientDetailsArguments).basicOnly, isTrue);
      expect(find.text('client@example.test'), findsOneWidget);
      expect(api.calls.where((s) => s.contains('/clients/')).toList(), [
        '/Therapists/clients/101/profile',
      ]);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(vm.day, day);
      expect(api.puts, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

Map<String, dynamic> _page(List<dynamic> items, int page, int pages) => {
  'items': items,
  'pageNumber': page,
  'totalPages': pages,
  'totalCount': 4,
  'pageSize': 2,
};

class _Api extends ApiClient {
  _Api() : super(sessionStorage: SessionStorageService());
  final calls = <String>[];
  bool absence = false, completed = false, fail = false, rejected = false;
  bool emptySchedule = false, breakSchedule = false;
  int puts = 0;
  String? reason;
  Completer<dynamic>? hold;
  late final therapists = TherapistRepository(
    therapistApiService: TherapistApiService(apiClient: this),
  );
  TherapistAppointmentsViewModel model() => TherapistAppointmentsViewModel(
    repository: AppointmentRepository(
      apiService: AppointmentApiService(apiClient: this),
    ),
    therapistRepository: therapists,
    now: () => DateTime.utc(2026, 10, 29, 6),
  );
  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    calls.add(endpoint);
    if (fail) throw Exception('Profile unavailable');
    final u = Uri.parse(endpoint);
    final page = int.tryParse(u.queryParameters['pageNumber'] ?? '') ?? 1;
    if (u.path.endsWith('/profile')) {
      if (u.path.contains('/clients/')) {
        return {
          'clientId': 101,
          'fullName': 'Client Example',
          'email': 'client@example.test',
          'phoneNumber': '123',
        };
      }
      return {'therapistId': 1};
    }
    if (u.path.endsWith('/availability') && emptySchedule) return [];
    if (u.path.endsWith('/availability') && breakSchedule) {
      return [
        for (var d = 0; d < 7; d++) ...[
          {'dayOfWeek': d, 'startTime': '09:00:00', 'endTime': '10:00:00'},
          {'dayOfWeek': d, 'startTime': '11:00:00', 'endTime': '12:00:00'},
        ],
      ];
    }
    if (u.path.endsWith('/availability')) {
      return [
        for (var d = 0; d < 7; d++)
          {'dayOfWeek': d, 'startTime': '09:00:00', 'endTime': '12:00:00'},
      ];
    }
    if (u.path.endsWith('/unavailable-dates')) {
      return _page(
        absence && page == 2
            ? [
                {
                  'id': 1,
                  'startUtc': '2026-10-29T09:00:00Z',
                  'endUtc': '2026-10-29T10:00:00Z',
                  'reason': 'Absence',
                },
              ]
            : [],
        page,
        absence ? 2 : 1,
      );
    }
    if (u.path == '/Appointments/therapist') {
      final date = AppointmentTimeZone.fromInstant(
        DateTime.parse(u.queryParameters['fromUtc']!),
      );
      if (hold != null && date.day == 29) return hold!.future;
      Map<String, dynamic> a(int id, int hour, String status) => {
        'id': id,
        'therapistId': 1,
        'clientId': 101,
        'clientName': 'Client Example With A Very Long Name For Layout Testing',
        'therapistName': 'Therapist',
        'startUtc': DateTime.utc(
          date.year,
          date.month,
          date.day,
          hour - 1,
        ).toIso8601String(),
        'endUtc': DateTime.utc(
          date.year,
          date.month,
          date.day,
          hour,
        ).toIso8601String(),
        'status': status,
        'type': 'Online',
        'price': 80,
      };
      return _page(
        page == 1
            ? [
                a(1, 9, rejected ? 'Rejected' : 'Pending'),
                a(2, 10, 'Cancelled'),
              ]
            : [
                a(3, 11, 'Accepted'),
                a(4, 10, completed ? 'Completed' : 'Rejected'),
              ],
        page,
        2,
      );
    }
    throw StateError('Unexpected endpoint $endpoint');
  }

  @override
  Future<dynamic> put(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    puts++;
    reason = (body as Map<String, dynamic>)['reason'] as String?;
    rejected = true;
    return null;
  }
}
