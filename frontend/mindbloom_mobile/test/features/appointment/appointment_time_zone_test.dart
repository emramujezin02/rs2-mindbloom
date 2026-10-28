import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/core/time/appointment_time_zone.dart';
import 'package:mindbloom_mobile/features/appointment/data/repositories/appointment_repository.dart';
import 'package:mindbloom_mobile/features/appointment/data/models/unavailable_date_model.dart';
import 'package:mindbloom_mobile/features/appointment/data/services/appointment_api_service.dart';
import 'package:mindbloom_mobile/features/appointment/presentation/viewmodels/appointment_create_viewmodel.dart';
import 'package:mindbloom_mobile/features/appointment/presentation/widgets/available_slots_preview.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/therapist_availability_model.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  AppointmentCreateViewModel model(
    _Client client,
    DateTime date, {
    String start = '09:00:00',
    String end = '17:00:00',
  }) {
    final value = AppointmentCreateViewModel(
      repository: AppointmentRepository(
        apiService: AppointmentApiService(apiClient: client),
      ),
      now: () => DateTime.utc(2025),
    );
    value.availabilities = [
      TherapistAvailabilityModel(
        id: 1,
        dayOfWeek: date.weekday % 7,
        startTime: start,
        endTime: end,
      ),
    ];
    addTearDown(value.dispose);
    return value;
  }

  for (final example in [(7, 6, 7), (1, 5, 8)]) {
    test(
      'Sarajevo 09:00 ${example.$1}/2026 sends ${example.$3}:00 UTC and keeps one real hour',
      () async {
        final api = _Client();
        final date = DateTime.utc(2026, example.$1, example.$2);
        final vm = model(api, date);
        await vm.loadAvailableSlots(therapistId: 1, date: date);
        expect(vm.availableSlots, hasLength(8));
        final slot = vm.availableSlots.first;
        expect(DateFormat('HH:mm').format(slot), '09:00');
        expect(
          slot.toUtc(),
          DateTime.utc(2026, example.$1, example.$2, example.$3),
        );
        expect(
          DateFormat(
            'HH:mm',
          ).format(vm.availableSlots.last.add(const Duration(hours: 1))),
          '17:00',
        );
        expect(
          await vm.createAppointment(
            therapistId: 1,
            startUtc: slot.toUtc(),
            endUtc: slot.toUtc().add(const Duration(hours: 1)),
            type: 1,
          ),
          isTrue,
        );
        expect(api.body!['startUtc'], slot.toUtc().toIso8601String());
        expect(
          api.body!['endUtc'],
          slot.toUtc().add(const Duration(hours: 1)).toIso8601String(),
        );
        expect(
          Uri.parse(api.lastGet!).queryParameters['date'],
          DateFormat('yyyy-MM-dd').format(date),
        );
      },
    );
  }

  test(
    'occupied and unavailable UTC intervals exclude the same Sarajevo instants',
    () async {
      final api = _Client()
        ..occupied = [
          {'startUtc': '2026-07-06T07:00:00', 'endUtc': '2026-07-06T08:00:00Z'},
        ];
      final date = DateTime.utc(2026, 7, 6);
      final vm = model(api, date);
      vm.unavailableDates = [
        UnavailableDateModel(
          id: 1,
          startUtc: DateTime.utc(2026, 7, 6, 9),
          endUtc: DateTime.utc(2026, 7, 6, 10),
          reason: 'Test',
        ),
      ];
      await vm.loadAvailableSlots(therapistId: 1, date: date);
      expect(vm.availableSlots, hasLength(6));
      expect(vm.availableSlots.first.hour, 10);
      expect(vm.availableSlots.any((slot) => slot.hour == 11), isFalse);
      expect(vm.occupiedSlots.single.startUtc.isUtc, isTrue);
    },
  );

  for (final date in [DateTime.utc(2026, 3, 29), DateTime.utc(2026, 10, 25)]) {
    test(
      'DST ${date.month} excludes nonexistent or ambiguous local slots',
      () async {
        final vm = model(_Client(), date, start: '00:00:00', end: '06:00:00');
        await vm.loadAvailableSlots(therapistId: 1, date: date);
        expect(vm.availableSlots.any((s) => s.hour == 2), isFalse);
        expect(
          vm.availableSlots.every(
            (s) =>
                s.add(const Duration(hours: 1)).difference(s) ==
                const Duration(hours: 1),
          ),
          isTrue,
        );
        expect(vm.availableSlots.any((s) => s.hour == 3), isTrue);
        if (date.month == 3) {
          final before = vm.availableSlots.singleWhere((s) => s.hour == 1);
          expect(before.add(const Duration(hours: 1)).hour, 3);
        }
      },
    );
  }

  test('gap and both repeated-hour offsets are not silently resolved', () {
    expect(
      AppointmentTimeZone.uniqueLocal(DateTime.utc(2026, 3, 29, 2, 30)),
      isNull,
    );
    expect(
      AppointmentTimeZone.uniqueLocal(DateTime.utc(2026, 10, 25, 2, 30)),
      isNull,
    );
  });

  test('instant conversion ignores the originating device zone', () {
    final utc = DateTime.utc(2026, 7, 6, 7);
    for (final id in ['America/New_York', 'Asia/Tokyo', 'Pacific/Auckland']) {
      final device = tz.TZDateTime.from(utc, tz.getLocation(id));
      final sarajevo = AppointmentTimeZone.fromInstant(device);
      expect(sarajevo.hour, 9);
      expect(sarajevo.toUtc(), utc);
    }
  });

  test('local midnight belongs to previous UTC date', () {
    final slot = AppointmentTimeZone.uniqueLocal(
      DateTime.utc(2026, 7, 6, 0, 15),
    )!;
    expect(slot.toUtc(), DateTime.utc(2026, 7, 5, 22, 15));
    expect(slot.day, 6);
  });

  test(
    'empty and failed occupied-slot requests keep existing loading/error behavior',
    () async {
      final api = _Client();
      final vm = model(api, DateTime.utc(2026, 7, 6));
      api.fail = true;
      await vm.loadAvailableSlots(
        therapistId: 1,
        date: DateTime.utc(2026, 7, 6),
      );
      expect(vm.error, isNotNull);
      expect(vm.isLoadingSlots, isFalse);
      expect(vm.availableSlots, isEmpty);
    },
  );

  testWidgets(
    'preview renders Sarajevo 09:00 and passes the same instant to booking',
    (tester) async {
      final slot = AppointmentTimeZone.fromInstant(DateTime.utc(2026, 7, 6, 7));
      DateTime? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvailableSlotsPreview(
              isLoading: false,
              groupedSlots: {
                DateTime.utc(2026, 7, 6): [slot],
              },
              onBookSlot: (value) => selected = value,
              onShowAllSlots: () {},
            ),
          ),
        ),
      );
      expect(find.text('09:00'), findsOneWidget);
      await tester.tap(find.text('09:00'));
      expect(selected!.toUtc(), DateTime.utc(2026, 7, 6, 7));
    },
  );
}

class _Client extends ApiClient {
  _Client() : super(sessionStorage: SessionStorageService());
  List<Map<String, dynamic>> occupied = [];
  Map<String, dynamic>? body;
  String? lastGet;
  bool fail = false;
  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    lastGet = endpoint;
    if (fail) throw StateError('Test API failure');
    return occupied;
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
    String? idempotencyKey,
  }) async {
    this.body = body as Map<String, dynamic>?;
    return {};
  }
}
