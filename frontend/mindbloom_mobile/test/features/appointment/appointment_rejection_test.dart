import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/features/notification/data/models/notification_model.dart';
import 'package:mindbloom_mobile/features/notification/data/repositories/notification_repository.dart';
import 'package:mindbloom_mobile/features/notification/data/services/notification_api_service.dart';
import 'package:mindbloom_mobile/features/notification/data/services/notification_realtime_service.dart';
import 'package:mindbloom_mobile/features/notification/presentation/pages/notification_page.dart';
import 'package:mindbloom_mobile/features/notification/presentation/viewmodels/notification_scope.dart';
import 'package:mindbloom_mobile/features/notification/presentation/viewmodels/notification_viewmodel.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';
import 'package:mindbloom_mobile/features/appointment/data/models/appointment_model.dart';
import 'package:mindbloom_mobile/features/appointment/data/models/therapist_appointment_status.dart';
import 'package:mindbloom_mobile/features/appointment/data/repositories/appointment_repository.dart';
import 'package:mindbloom_mobile/features/appointment/data/services/appointment_api_service.dart';
import 'package:mindbloom_mobile/features/appointment/presentation/viewmodels/therapist_appointments_viewmodel.dart';
import 'package:mindbloom_mobile/features/appointment/presentation/widgets/appointment_rejection_dialog.dart';

void main() {
  testWidgets('Reason longer than the backend limit is rejected', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentRejectionDialog(
          onReject: (_) async {
            calls++;
            return null;
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'x' * 501);
    await tester.tap(find.text('Reject'));
    await tester.pump();
    expect(
      find.text('The reason may contain at most 500 characters.'),
      findsOneWidget,
    );
    expect(calls, 0);
  });

  testWidgets('Client notification page displays the rejection reason', (
    tester,
  ) async {
    const message =
        'Your appointment has been rejected. Reason: Nisam u mogućnosti održati termin.';
    final model = NotificationViewModel(
      repository: NotificationRepository(
        apiService: NotificationApiService(apiClient: _Client()),
      ),
      realtimeServiceFactory:
          ({
            required onNotificationReceived,
            required onReconnected,
            required onConnectionStatusChanged,
          }) => NotificationRealtimeService(
            sessionStorage: SessionStorageService(),
            onNotificationReceived: onNotificationReceived,
            onReconnected: onReconnected,
            onConnectionStatusChanged: onConnectionStatusChanged,
          ),
    );
    model.isInitialized = true;
    model.notifications = [
      NotificationModel.fromJson({
        'id': 1,
        'title': 'Appointment rejected',
        'message': message,
        'isRead': true,
        'createdAtUtc': '2026-10-29T12:00:00Z',
        'actionType': 'Appointment',
      }),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScope(
          notificationViewModel: model,
          child: const NotificationPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  Future<void> open(
    WidgetTester tester,
    Future<String?> Function(String) reject,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showAppointmentRejectionDialog(context, onReject: reject),
              child: const Text('Open rejection'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open rejection'));
    await tester.pumpAndSettle();
    expect(find.text('Reject appointment?'), findsOneWidget);
  }

  for (final reason in ['', '   ', 'abcd', '  abcd  ']) {
    testWidgets('Invalid trimmed reason "$reason" never sends', (tester) async {
      var calls = 0;
      await open(tester, (_) async {
        calls++;
        return null;
      });
      await tester.enterText(find.byType(TextFormField), reason);
      await tester.tap(find.text('Reject'));
      await tester.pump();
      expect(
        find.text('Enter a reason with at least 5 characters.'),
        findsOneWidget,
      );
      expect(calls, 0);
    });
  }

  for (final reason in [
    'abcde',
    '  abcde  ',
    'Nisam u mogućnosti održati termin.',
  ]) {
    testWidgets('Valid reason is trimmed and sent: $reason', (tester) async {
      String? sent;
      await open(tester, (value) async {
        sent = value;
        return null;
      });
      await tester.enterText(find.byType(TextFormField), reason);
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(sent, reason.trim());
      expect(find.byType(AppointmentRejectionDialog), findsNothing);
    });
  }

  testWidgets('Cancel sends nothing', (tester) async {
    var calls = 0;
    await open(tester, (_) async {
      calls++;
      return null;
    });
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(AppointmentRejectionDialog), findsNothing);
  });

  testWidgets('API error stays visible and permits retry', (tester) async {
    await open(tester, (_) async => 'The appointment is no longer pending.');
    await tester.enterText(find.byType(TextFormField), 'Valid reason');
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(find.text('The appointment is no longer pending.'), findsOneWidget);
    expect(find.byType(AppointmentRejectionDialog), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('Loading prevents duplicate requests and disposal is safe', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<String?>();
    await open(tester, (_) {
      calls++;
      return pending.future;
    });
    await tester.enterText(find.byType(TextFormField), 'Valid reason');
    await tester.tap(find.text('Reject'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    pending.complete(null);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test(
    'ViewModel sends reason through repository and API then refreshes once',
    () async {
      final client = _Client();
      final model = TherapistAppointmentsViewModel(
        repository: AppointmentRepository(
          apiService: AppointmentApiService(apiClient: client),
        ),
      );
      final appointment = AppointmentModel(
        id: 7,
        therapistId: 1,
        therapistName: 'Test',
        clientName: 'Client',
        startUtc: DateTime.utc(2030),
        endUtc: DateTime.utc(2030).add(const Duration(hours: 1)),
        status: 'Pending',
        type: 'Online',
        price: 20,
      );
      final first = model.updateStatus(
        appointment: appointment,
        status: TherapistAppointmentStatus.rejected,
        reason: '  Valid reason  ',
      );
      final second = await model.updateStatus(
        appointment: appointment,
        status: TherapistAppointmentStatus.rejected,
        reason: 'Another reason',
      );
      expect(second, isFalse);
      expect(await first, isTrue);
      expect(client.calls, 1);
      expect(client.endpoint, '/Appointments/status');
      expect(client.body, {
        'appointmentId': 7,
        'status': 2,
        'reason': 'Valid reason',
      });
      expect(client.gets, 1);
      model.dispose();
    },
  );
}

class _Client extends ApiClient {
  _Client() : super(sessionStorage: SessionStorageService());
  int calls = 0;
  int gets = 0;
  Object? body;
  String? endpoint;
  @override
  Future<dynamic> put(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    calls++;
    this.endpoint = endpoint;
    this.body = body;
    await Future<void>.delayed(Duration.zero);
    return null;
  }

  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    gets++;
    return {'items': [], 'pageNumber': 1, 'totalPages': 0};
  }
}
