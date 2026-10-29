import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/core/error/app_exception.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/core/time/appointment_time_zone.dart';
import 'package:mindbloom_mobile/features/appointment/data/repositories/appointment_repository.dart';
import 'package:mindbloom_mobile/features/appointment/data/services/appointment_api_service.dart';
import 'package:mindbloom_mobile/features/appointment/presentation/pages/appointment_create_page.dart';
import 'package:mindbloom_mobile/features/appointment/presentation/viewmodels/appointment_create_viewmodel.dart';
import 'package:mindbloom_mobile/features/appointment/presentation/widgets/booking_calendar.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/therapist_model.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

final _today = DateTime.utc(2026, 10, 29);
const _day = Key('day-2026-10-29');
const _next = Key('booking-next');
const _back = Key('booking-back');

AppointmentCreateViewModel _model(_Api api, {DateTime? now}) =>
    AppointmentCreateViewModel(
      repository: AppointmentRepository(
        apiService: AppointmentApiService(apiClient: api),
      ),
      now: () => now ?? DateTime.utc(2026, 10, 29, 6),
    );

TherapistModel _therapist({bool online = true, bool inPerson = true}) =>
    TherapistModel.fromJson({
      'id': 1,
      'fullName': 'Dr. Dugo Ime Psihoterapeuta za provjeru prikaza',
      'hourlyRate': 80,
      'offersOnline': online,
      'offersInPerson': inPerson,
      'address': 'Adresa 1',
    });

Future<void> _tap(WidgetTester tester, Finder finder) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _slot(int utcHour) => find.byKey(
  Key('slot-${DateTime.utc(2026, 10, 29, utcHour).toIso8601String()}'),
);

Future<void> _open(
  WidgetTester tester,
  _Api api, {
  TherapistModel? therapist,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AppointmentCreatePage(
        therapist: therapist ?? _therapist(),
        viewModel: _model(api),
        returnResultOnSuccess: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _confirmStep(WidgetTester tester) async {
  await _tap(tester, find.byKey(_day));
  await _tap(tester, find.byKey(_next));
  await _tap(tester, _slot(9)); // Sarajevo 10:00 in winter.
  await _tap(tester, find.byKey(_next));
}

void main() {
  group('booking unit', () {
    test(
      'occupied slots remain visible while preview only exposes free slots',
      () async {
        final vm = _model(_Api());
        addTearDown(vm.dispose);
        await vm.loadBookingData(1);
        await vm.loadAvailableSlots(therapistId: 1, date: _today);
        expect(vm.bookingSlots, hasLength(3));
        expect(vm.availableSlots, hasLength(2));
        expect(vm.bookingSlots.first.isOccupied, isTrue);
        expect(vm.bookingSlots.first.unavailableReason, 'Zauzeto');
        expect(
          vm.bookingSlots.every(
            (s) => s.end.difference(s.start) == const Duration(hours: 1),
          ),
          isTrue,
        );
        expect(vm.bookingSlots.first.start.hour, 9);
        expect(vm.availableSlots.first.toUtc(), DateTime.utc(2026, 10, 29, 9));
      },
    );

    test(
      'absence on a later API page is excluded, not shown as occupied',
      () async {
        final api = _Api()..absencePages = true;
        final vm = _model(api);
        addTearDown(vm.dispose);
        await vm.loadBookingData(1);
        await vm.loadAvailableSlots(therapistId: 1, date: _today);
        expect(api.absenceRequests, 2);
        expect(vm.bookingSlots.map((s) => s.start.hour), [9, 10]);
      },
    );

    test(
      'calendar enforces past, horizon, and published working days',
      () async {
        final vm = _model(_Api());
        addTearDown(vm.dispose);
        await vm.loadBookingData(1);
        expect(
          vm.isDateSelectable(_today.subtract(const Duration(days: 1))),
          isFalse,
        );
        expect(
          vm.isDateSelectable(vm.lastBookingDate.add(const Duration(days: 1))),
          isFalse,
        );
        expect(vm.isDateSelectable(_today), isTrue);
        vm.availabilities = [];
        expect(vm.isDateSelectable(_today), isFalse);
      },
    );

    test('a slot starting exactly now is not offered', () async {
      final vm = _model(_Api(), now: DateTime.utc(2026, 10, 29, 8));
      addTearDown(vm.dispose);
      await vm.loadBookingData(1);
      await vm.loadAvailableSlots(therapistId: 1, date: _today);
      expect(vm.bookingSlots.map((s) => s.start.hour), [10, 11]);
    });

    test('overlapping schedules do not duplicate slot buttons', () async {
      final vm = _model(_Api());
      addTearDown(vm.dispose);
      await vm.loadBookingData(1);
      vm.availabilities.addAll(vm.availabilities.toList());
      await vm.loadAvailableSlots(therapistId: 1, date: _today);
      expect(vm.bookingSlots, hasLength(3));
    });

    test(
      'late response for previous date cannot replace current date slots',
      () async {
        final api = _Api()..delayFirstDay = Completer<dynamic>();
        final vm = _model(api);
        addTearDown(vm.dispose);
        await vm.loadBookingData(1);
        final first = vm.loadAvailableSlots(therapistId: 1, date: _today);
        await vm.loadAvailableSlots(
          therapistId: 1,
          date: _today.add(const Duration(days: 1)),
        );
        api.delayFirstDay!.complete([]);
        await first;
        expect(vm.bookingSlots.every((s) => s.start.day == 30), isTrue);
        expect(vm.isLoadingSlots, isFalse);
      },
    );

    test(
      'dispose during slot request does not notify a disposed model',
      () async {
        final api = _Api()..delayFirstDay = Completer<dynamic>();
        final vm = _model(api);
        await vm.loadBookingData(1);
        final request = vm.loadAvailableSlots(therapistId: 1, date: _today);
        vm.dispose();
        api.delayFirstDay!.complete([]);
        await request;
      },
    );
  });

  test(
    'Sarajevo calendar starts in its month even when UTC is previous month',
    () {
      final vm = _model(_Api(), now: DateTime.utc(2026, 10, 31, 23, 30));
      addTearDown(vm.dispose);
      expect(vm.today, DateTime.utc(2026, 11, 1));
    },
  );

  test('a last working-hour slot may end at local midnight', () async {
    final vm = _model(_Api()..lateSchedule = true);
    addTearDown(vm.dispose);
    await vm.loadBookingData(1);
    await vm.loadAvailableSlots(therapistId: 1, date: _today);
    final slot = vm.bookingSlots.single;
    expect(slot.start.hour, 23);
    expect(slot.end.hour, 0);
    expect(slot.end.day, 30);
    expect(
      slot.end.toUtc().difference(slot.start.toUtc()),
      const Duration(hours: 1),
    );
  });

  group('booking calendar widgets', () {
    Future<void> calendar(
      WidgetTester tester, {
      DateTime? today,
      DateTime? selected,
      ValueChanged<DateTime>? onSelected,
    }) async {
      final start = today ?? _today;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingCalendar(
              today: start,
              lastDate: start.add(const Duration(days: 365)),
              selectedDate: selected,
              isSelectable: (date) => date.weekday != DateTime.sunday,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('inline calendar has month arrows and no date dialog', (
      tester,
    ) async {
      await calendar(tester);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.byType(DatePickerDialog), findsNothing);
      await tester.tap(find.byKey(const Key('next-month')));
      await tester.pump();
      expect(find.text('November 2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('previous-month')));
      await tester.pump();
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('past and nonworking days are disabled, valid day selects', (
      tester,
    ) async {
      DateTime? chosen;
      await calendar(tester, onSelected: (date) => chosen = date);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('day-2026-10-28')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(_day));
      expect(chosen, _today);
      await tester.tap(find.byKey(const Key('next-month')));
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('day-2026-11-01')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('month arrows cross year boundary and preserve selection', (
      tester,
    ) async {
      await calendar(
        tester,
        today: DateTime.utc(2026, 12, 30),
        selected: DateTime.utc(2026, 12, 31),
      );
      await tester.tap(find.byKey(const Key('next-month')));
      await tester.pump();
      expect(find.text('January 2027'), findsOneWidget);
      await tester.tap(find.byKey(const Key('previous-month')));
      await tester.pump();
      expect(find.text('December 2026'), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.byKey(const Key('day-2026-12-31')),
      );
      expect(button.style!.backgroundColor!.resolve({}), isNotNull);
    });
  });

  group('booking page widgets', () {
    testWidgets(
      'exactly three steps, no skipping, no API fetch on month browsing',
      (tester) async {
        final api = _Api();
        await _open(tester, api);
        expect(find.byType(Stepper), findsNothing);
        expect(find.text('Korak 1 od 3'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(_next),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester.widget<FilledButton>(find.byKey(_next)).onPressed,
          isNull,
        );
        await _tap(tester, find.byKey(const Key('next-month')));
        await _tap(tester, find.byKey(const Key('previous-month')));
        expect(api.occupiedRequests, 0);
        await _tap(tester, find.byKey(_day));
        await _tap(tester, find.byKey(_next));
        expect(find.text('Korak 2 od 3'), findsOneWidget);
        expect(find.text('Izbor termina'), findsOneWidget);
      },
    );

    testWidgets(
      'occupied time is dark, labelled, disabled; free time selectable',
      (tester) async {
        await _open(tester, _Api());
        await _tap(tester, find.byKey(_day));
        await _tap(tester, find.byKey(_next));
        final occupied = tester.widget<OutlinedButton>(_slot(8));
        expect(occupied.onPressed, isNull);
        expect(find.textContaining('Zauzeto'), findsOneWidget);
        expect(
          occupied.style!.backgroundColor!.resolve({WidgetState.disabled}),
          const Color(0xFFD4CEDB),
        );
        await _tap(tester, _slot(9));
        await _tap(tester, find.byKey(_next));
        expect(find.text('Korak 3 od 3'), findsOneWidget);
        expect(find.text('Potvrda'), findsOneWidget);
      },
    );

    testWidgets('confirmation keeps notes, type, price and NE never creates', (
      tester,
    ) async {
      final api = _Api();
      await _open(tester, api);
      await _confirmStep(tester);
      await _tap(tester, find.text('In-person session'));
      await tester.enterText(
        find.byKey(const Key('booking-notes')),
        '  Razgovor o stresu  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await _tap(tester, find.byKey(_back));
      expect(api.posts, 0);
      await _tap(tester, find.byKey(_next));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('booking-notes')))
            .controller!
            .text,
        '  Razgovor o stresu  ',
      );
      await _tap(tester, find.byKey(_next));
      expect(api.posts, 1);
      expect(api.body!['type'], 2);
      expect(api.body!['notes'], 'Razgovor o stresu');
      expect(api.body!['location'], 'Adresa 1');
      expect(api.body!['startUtc'], '2026-10-29T09:00:00.000Z');
      expect(api.body!['endUtc'], '2026-10-29T10:00:00.000Z');
      expect(api.idempotencyKey, isNotEmpty);
      expect(
        find.text('Appointment request sent successfully'),
        findsOneWidget,
      );
    });

    testWidgets(
      '409 refreshes occupancy and returns to time selection without success',
      (tester) async {
        final api = _Api()..failPost = 409;
        await _open(tester, api);
        await _confirmStep(tester);
        await _tap(tester, find.byKey(_next));
        expect(api.posts, 1);
        expect(api.occupiedRequests, 3);
        expect(find.text('Izbor termina'), findsOneWidget);
        expect(tester.widget<OutlinedButton>(_slot(9)).onPressed, isNull);
        expect(
          find.text('Appointment request sent successfully'),
          findsNothing,
        );
        expect(find.text('Slot already booked'), findsOneWidget);
      },
    );

    testWidgets('server error retains inputs and never reports success', (
      tester,
    ) async {
      final api = _Api()..failPost = 500;
      await _open(tester, api);
      await _confirmStep(tester);
      await _tap(tester, find.byKey(_next));
      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text('Potvrda'), findsOneWidget);
      expect(find.textContaining('Safe API error'), findsWidgets);
      expect(find.text('Appointment request sent successfully'), findsNothing);
    });

    testWidgets('DA double click during slow request creates only once', (
      tester,
    ) async {
      final api = _Api()..pendingPost = Completer<dynamic>();
      await _open(tester, api);
      await _confirmStep(tester);
      await tester.scrollUntilVisible(
        find.byKey(_next),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(_next));
      await tester.pump();
      await tester.tap(find.byKey(_next));
      await tester.pump();
      expect(api.posts, 1);
      api.pendingPost!.complete({});
      await tester.pumpAndSettle();
      expect(api.posts, 1);
    });

    testWidgets('preflight detects newly occupied slot without sending POST', (
      tester,
    ) async {
      final api = _Api();
      await _open(tester, api);
      await _confirmStep(tester);
      api.allOccupied = true;
      await _tap(tester, find.byKey(_next));
      expect(api.posts, 0);
      expect(find.text('Izbor termina'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(_slot(9)).onPressed, isNull);
    });

    testWidgets('failed preflight can retry without losing notes or creating', (
      tester,
    ) async {
      final api = _Api();
      await _open(tester, api);
      await _confirmStep(tester);
      await tester.enterText(
        find.byKey(const Key('booking-notes')),
        'Sačuvana napomena',
      );
      api.failGet = true;
      await _tap(tester, find.byKey(_next));
      expect(api.posts, 0);
      expect(find.text('Izbor termina'), findsOneWidget);
      api.failGet = false;
      await _tap(tester, find.text('Pokušaj ponovo'));
      await _tap(tester, _slot(9));
      await _tap(tester, find.byKey(_next));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('booking-notes')))
            .controller!
            .text,
        'Sačuvana napomena',
      );
    });

    testWidgets(
      'client overlap message is preserved without marking free therapist occupied',
      (tester) async {
        final api = _Api()
          ..failPost = 409
          ..clientConflict = true;
        await _open(tester, api);
        await _confirmStep(tester);
        await _tap(tester, find.byKey(_next));
        expect(api.posts, 1);
        expect(
          find.text('You already have an appointment during this time.'),
          findsOneWidget,
        );
        expect(tester.widget<OutlinedButton>(_slot(9)).onPressed, isNotNull);
        expect(
          find.text('Appointment request sent successfully'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'profile preselection keeps all three steps and the same UTC instant',
      (tester) async {
        final api = _Api();
        await tester.pumpWidget(
          MaterialApp(
            home: AppointmentCreatePage(
              therapist: _therapist(),
              viewModel: _model(api),
              initialSlot: DateTime.utc(2026, 10, 29, 9),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Korak 1 od 3'), findsOneWidget);
        await _tap(tester, find.byKey(_next));
        expect(find.text('Korak 2 od 3'), findsOneWidget);
        await _tap(tester, find.byKey(_next));
        expect(find.text('Korak 3 od 3'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('80.00 USD'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('80.00 USD'), findsOneWidget);
        expect(find.text('29.10.2026.'), findsOneWidget);
        expect(find.text('10:00 - 11:00'), findsOneWidget);
        expect(api.posts, 0);
      },
    );

    testWidgets('all occupied slots remain visible and cannot advance', (
      tester,
    ) async {
      final api = _Api()..allOccupied = true;
      await _open(tester, api);
      await _tap(tester, find.byKey(_day));
      await _tap(tester, find.byKey(_next));
      expect(find.textContaining('Zauzeto'), findsNWidgets(3));
      await tester.scrollUntilVisible(
        find.byKey(_next),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(find.byKey(_next)).onPressed, isNull);
    });

    testWidgets('date change clears slot, device back returns to date step', (
      tester,
    ) async {
      final api = _Api();
      await _open(tester, api);
      await _confirmStep(tester);
      await _tap(tester, find.byKey(_back));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Izbor datuma'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('day-2026-10-30')));
      await _tap(tester, find.byKey(_next));
      await tester.scrollUntilVisible(
        find.byKey(_next),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(find.byKey(_next)).onPressed, isNull);
      expect(api.posts, 0);
    });

    testWidgets(
      'small screen and keyboard scroll without overflow or lost notes',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _open(tester, _Api());
        await _confirmStep(tester);
        await tester.ensureVisible(find.byKey(const Key('booking-notes')));
        await tester.enterText(
          find.byKey(const Key('booking-notes')),
          'Važna napomena ' * 60,
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(_next),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('DA'), findsOneWidget);
      },
    );

    testWidgets(
      'empty schedule disables date selection and retry handles API failure',
      (tester) async {
        final api = _Api()..failGet = true;
        await _open(tester, api);
        expect(find.byKey(const Key('booking-error')), findsOneWidget);
        api.failGet = false;
        api.emptySchedule = true;
        await _tap(tester, find.text('Pokušaj ponovo'));
        expect(
          find.text('Terapeut još nije objavio raspored.'),
          findsOneWidget,
        );
        expect(tester.widget<TextButton>(find.byKey(_day)).onPressed, isNull);
      },
    );
  });
}

class _Api extends ApiClient {
  _Api() : super(sessionStorage: SessionStorageService());
  int posts = 0;
  int occupiedRequests = 0;
  int absenceRequests = 0;
  int? failPost;
  bool failGet = false;
  bool allOccupied = false;
  bool emptySchedule = false;
  bool absencePages = false;
  bool secondBooked = false;
  bool clientConflict = false;
  bool lateSchedule = false;
  Completer<dynamic>? pendingPost;
  Completer<dynamic>? delayFirstDay;
  Map<String, dynamic>? body;
  String? idempotencyKey;

  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    if (failGet) {
      throw const AppException(message: 'Safe API error', statusCode: 503);
    }
    final uri = Uri.parse(endpoint);
    if (uri.path.endsWith('/availability')) {
      return emptySchedule
          ? []
          : [
              for (var i = 0; i < 7; i++)
                {
                  'id': i + 1,
                  'dayOfWeek': i,
                  'startTime': lateSchedule ? '23:00:00' : '09:00:00',
                  'endTime': lateSchedule ? '24:00:00' : '12:00:00',
                },
            ];
    }
    if (uri.path.endsWith('/unavailable-dates')) {
      absenceRequests++;
      final page = int.parse(uri.queryParameters['pageNumber']!);
      return {
        'items': absencePages && page == 2
            ? [
                {
                  'id': 1,
                  'startUtc': '2026-10-29T10:00:00Z',
                  'endUtc': '2026-10-29T11:00:00Z',
                  'reason': 'Private absence',
                },
              ]
            : [],
        'pageNumber': page,
        'totalPages': absencePages ? 2 : 0,
      };
    }
    occupiedRequests++;
    if (uri.queryParameters['date'] == '2026-10-29' && delayFirstDay != null) {
      return delayFirstDay!.future;
    }
    final date = DateTime.parse(uri.queryParameters['date']!);
    final start = AppointmentTimeZone.uniqueLocal(
      DateTime.utc(date.year, date.month, date.day, 9),
    )!.toUtc();
    return [
      {
        'startUtc': start.toIso8601String(),
        'endUtc': start
            .add(
              Duration(
                hours: allOccupied
                    ? 3
                    : secondBooked
                    ? 2
                    : 1,
              ),
            )
            .toIso8601String(),
      },
    ];
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
    String? idempotencyKey,
  }) async {
    posts++;
    this.body = body as Map<String, dynamic>;
    this.idempotencyKey = idempotencyKey;
    if (failPost != null) {
      secondBooked = failPost == 409 && !clientConflict;
      throw AppException(
        message: clientConflict
            ? 'You already have an appointment during this time.'
            : failPost == 409
            ? 'Slot already booked'
            : 'Safe API error',
        statusCode: failPost,
      );
    }
    return pendingPost == null ? {} : pendingPost!.future;
  }
}
