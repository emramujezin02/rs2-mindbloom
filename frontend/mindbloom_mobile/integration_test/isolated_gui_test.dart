import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:mindbloom_mobile/core/constants/api_constants.dart';
import 'package:mindbloom_mobile/core/time/appointment_time_zone.dart';
import 'package:mindbloom_mobile/core/widgets/public_footer.dart';
import 'package:mindbloom_mobile/features/article/presentation/pages/article_list_page.dart';
import 'package:mindbloom_mobile/features/notification/presentation/pages/notification_page.dart';
import 'package:mindbloom_mobile/features/notification/presentation/viewmodels/notification_scope.dart';
import 'package:mindbloom_mobile/main.dart' as application;

// Opt-in device tests. Requires the separately approved QA host and fresh emulator
// storage. Credentials are injected into the debug app's private files directory,
// never committed or sent to the normal Docker API.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final evidence = <String, dynamic>{};
  late Map<String, dynamic> config;

  Future<void> waitFor(
    WidgetTester tester,
    Finder target, {
    int seconds = 45,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    while (target.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(target, findsWidgets, reason: 'Expected GUI target: $target');
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await waitFor(tester, target);
    await tester.ensureVisible(target.first);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(target.first);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> start(WidgetTester tester) async {
    expect(Uri.parse(ApiConstants.baseUrl).port, 8082);
    expect(Uri.parse(ApiConstants.baseUrl).host, '10.0.2.2');
    config =
        jsonDecode(
              await File(
                '/data/user/0/com.example.mindbloom_mobile/files/qa-config.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(config['runId'], matches(RegExp(r'^[a-f0-9]{32}$')));
    final errorHandler = FlutterError.onError;
    await application.main();
    FlutterError.onError = errorHandler;
    await tester.pump(const Duration(seconds: 2));
    binding.reportData = evidence;
  }

  Future<void> login(WidgetTester tester, String email) async {
    if (find.widgetWithText(TextFormField, 'Email').evaluate().isEmpty) {
      final menu = find.byTooltip('Menu');
      await tap(tester, menu);
      await tap(tester, find.text('Log in'));
    }
    await waitFor(tester, find.widgetWithText(TextFormField, 'Email'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      config['password'] as String,
    );
    await tap(tester, find.widgetWithText(ElevatedButton, 'Login'));
    await waitFor(tester, find.byTooltip('Notifikacije'), seconds: 90);
  }

  Future<void> logout(WidgetTester tester) async {
    await tap(tester, find.byTooltip('Open navigation menu'));
    await tap(tester, find.text('Odjava'));
    await waitFor(tester, find.widgetWithText(TextFormField, 'Email'));
  }

  testWidgets('GUI footer legal routes and disabled unconfigured social links', (
    tester,
  ) async {
    await start(tester);
    await login(tester, config['clientEmail'] as String);
    await tap(tester, find.byTooltip('Open navigation menu'));
    await tap(tester, find.text('Članci'));
    await waitFor(tester, find.byType(ArticleListPage));
    await waitFor(tester, find.text('Read article'));
    final footer = find.byType(PublicFooter).first;
    final scrollable = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      footer,
      500,
      scrollable: scrollable,
      maxScrolls: 30,
    );
    for (final label in [
      'O nama',
      'Uslovi korištenja',
      'Politika privatnosti',
    ]) {
      final link = find.descendant(of: footer, matching: find.text(label));
      await tap(tester, link);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BackButton), findsWidgets);
      evidence['footer-$label'] =
          'Opened through actual article-footer tap on Android; back returned to article list.';
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
    }
    for (final network in ['Instagram', 'Facebook', 'YouTube']) {
      final icon = find.byKey(ValueKey('footer-social-$network'));
      await waitFor(tester, icon);
      expect(tester.widget<IconButton>(icon.first).onPressed, isNull);
    }
    expect(find.textContaining('Demonstracijski podaci'), findsWidgets);
    evidence['footer-socials'] =
        'All three icons disabled; demo contacts visibly labelled.';
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    await logout(tester);
  });

  testWidgets(
    'Live RabbitMQ Worker notification appears in open Android GUI without refresh',
    (tester) async {
      await start(tester);
      await login(tester, config['therapistEmail'] as String);
      await tap(tester, find.byTooltip('Notifikacije'));
      await waitFor(tester, find.byType(NotificationPage));
      await waitFor(tester, find.text('No notifications'));
      final notificationContext = tester.element(find.byType(NotificationPage));
      final vm = NotificationScope.read(notificationContext);
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!vm.isRealtimeConnected && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(
        vm.isRealtimeConnected,
        isTrue,
        reason: 'Must prove polling while real SignalR is connected.',
      );
      evidence['signalRBeforeBooking'] = vm.connectionStatusText;
      final client = http.Client();
      try {
        final authResponse = await client.post(
          Uri.parse('${ApiConstants.apiBaseUrl}/Auth/login-2fa'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': config['clientEmail'],
            'password': config['password'],
          }),
        );
        expect(authResponse.statusCode, 200);
        final auth = jsonDecode(authResponse.body) as Map<String, dynamic>;
        final token = (auth['auth'] as Map<String, dynamic>)['token'] as String;
        final local = AppointmentTimeZone.now();
        final date = DateTime.utc(local.year, local.month, local.day + 2, 14);
        final slot = AppointmentTimeZone.uniqueLocal(date)!;
        final booking = await client.post(
          Uri.parse('${ApiConstants.apiBaseUrl}/Appointments'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Idempotency-Key': 'qa-${config['runId']}-live-booking',
          },
          body: jsonEncode({
            'therapistId': config['therapistId'],
            'startUtc': slot.toUtc().toIso8601String(),
            'endUtc': slot
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'type': 1,
            'notes': 'Synthetic live Worker GUI verification',
          }),
        );
        expect(
          booking.statusCode,
          anyOf(200, 201),
          reason: 'Booking must commit through actual HTTP API.',
        );
        evidence['bookingStatus'] = booking.statusCode;
        final stopwatch = Stopwatch()..start();
        // No refresh(), fake timer, route re-entry or ReceiveNotification injection.
        await waitFor(
          tester,
          find.text('New appointment request'),
          seconds: 85,
        );
        expect(
          vm.notifications
              .where((n) => n.title == 'New appointment request')
              .length,
          1,
        );
        expect(vm.unreadCount, 1);
        expect(vm.isRealtimeConnected, isTrue);
        evidence['automaticAppearanceMilliseconds'] =
            stopwatch.elapsedMilliseconds;
        evidence['liveChain'] =
            'Real HTTP booking, SQL, RabbitMQ, production Worker consumer/handler, real REST polling, open Android Flutter GUI; external email/push disabled.';
        await tap(tester, find.text('Read all'));
        expect(vm.unreadCount, 0);
        await tester.pump(const Duration(seconds: 2));
        expect(vm.notifications.length, 1);
        evidence['readAll'] =
            'GUI action persisted, one item remains, unread badge state zero.';
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pump(const Duration(seconds: 1));
        final badges = tester.widgetList<Badge>(find.byType(Badge));
        expect(badges.every((badge) => !badge.isLabelVisible), isTrue);
        await logout(tester);
        expect(vm.notifications, isEmpty);
        expect(vm.unreadCount, 0);
        evidence['logoutIsolation'] =
            'Therapist GUI logout cleared notification state.';
      } finally {
        client.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
