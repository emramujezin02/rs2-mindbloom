import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:mindbloom_mobile/core/constants/api_constants.dart';
import 'package:mindbloom_mobile/core/time/appointment_time_zone.dart';
import 'package:mindbloom_mobile/features/appointment/presentation/widgets/booking_calendar.dart';
import 'package:mindbloom_mobile/features/article/presentation/pages/article_details_page.dart';
import 'package:mindbloom_mobile/features/article/presentation/widgets/article_pagination.dart';
import 'package:mindbloom_mobile/main.dart' as application;

// Device GUI tests against the separately provisioned QA host, never port 8080.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final evidence = <String, dynamic>{};
  late Map<String, dynamic> config;
  Future<void> wait(
    WidgetTester tester,
    Finder target, {
    int seconds = 60,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    while (target.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(target, findsWidgets, reason: 'Expected GUI target: $target');
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await wait(tester, target);
    await tester.ensureVisible(target.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(target.first);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> start(WidgetTester tester) async {
    expect(ApiConstants.baseUrl, 'http://10.0.2.2:8082');
    config =
        jsonDecode(
              await File(
                '/data/user/0/com.example.mindbloom_mobile/files/qa-config.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final errorHandler = FlutterError.onError;
    await application.main();
    FlutterError.onError = errorHandler;
    binding.reportData = evidence;
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> login(WidgetTester tester, String email) async {
    if (find.widgetWithText(TextFormField, 'Email').evaluate().isEmpty) {
      await tap(tester, find.byTooltip('Menu'));
      await tap(tester, find.text('Log in'));
    }
    await wait(tester, find.widgetWithText(TextFormField, 'Email'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      config['password'] as String,
    );
    await tap(tester, find.widgetWithText(ElevatedButton, 'Login'));
    await wait(tester, find.byTooltip('Notifikacije'), seconds: 90);
  }

  Future<void> drawer(WidgetTester tester, String label) async {
    await tap(tester, find.byTooltip('Open navigation menu'));
    await tap(tester, find.text(label));
  }

  Future<void> logout(WidgetTester tester) async {
    await drawer(tester, 'Odjava');
    await wait(tester, find.widgetWithText(TextFormField, 'Email'));
  }

  Future<Map<String, dynamic>> state() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/__qa/state'),
      headers: {'X-Qa-Key': config['controlKey'] as String},
    );
    expect(response.statusCode, 200);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    expect(data['database'], matches(RegExp(r'^MindBloomE2E_[a-f0-9]{32}$')));
    return data;
  }

  Future<void> selectDay(WidgetTester tester, DateTime date) async {
    final label =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    var target = find.byKey(ValueKey('day-$label'));
    for (var i = 0; i < 3 && target.evaluate().isEmpty; i++) {
      await tap(tester, find.byKey(const Key('next-month')));
    }
    await tap(tester, target);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
    'client GUI membership, three-step booking and real SQL result',
    (tester) async {
      await start(tester);
      await login(tester, config['clientEmail'] as String);
      await drawer(tester, 'Moje članstvo');
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('QA Therapist'), findsWidgets);
      evidence['membershipGui'] =
          'Opened existing synthetic paid membership through client drawer; no payment sheet.';
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      await tap(tester, find.text('Terapeuti'));
      await tap(tester, find.text('QA Therapist'));
      await tap(tester, find.text('Book appointment'));
      await wait(tester, find.byType(BookingCalendar));
      final local = AppointmentTimeZone.now();
      final day = DateTime.utc(local.year, local.month, local.day + 1);
      await selectDay(tester, day);
      await tap(tester, find.byKey(const Key('booking-next')));
      final available = find.byWidgetPredicate(
        (w) =>
            w is OutlinedButton &&
            w.key.toString().contains('slot-') &&
            w.onPressed != null,
      );
      await tap(tester, available);
      await tap(tester, find.byKey(const Key('booking-next')));
      await wait(tester, find.text('DA'));
      expect(find.text('NE'), findsOneWidget);
      final notes = find.byKey(const Key('booking-notes'));
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'QA client GUI booking note');
      tester.testTextInput.hide();
      final before = await state();
      await tap(tester, find.text('NE'));
      expect((await state())['appointments'], before['appointments']);
      await tap(tester, find.byKey(const Key('booking-next')));
      expect(
        tester.widget<TextFormField>(notes).controller!.text,
        'QA client GUI booking note',
      );
      await tap(tester, find.text('DA'));
      await wait(tester, find.text('Appointment request sent successfully'));
      expect(
        (await state())['appointments'],
        (before['appointments'] as int) + 1,
      );
      evidence['bookingGui'] =
          'Calendar date, enabled slot, notes, NE without write, preserved input, DA created exactly one SQL appointment.';
      await tap(tester, find.text('Return to therapist'));
      await tester.pageBack();
      await tester.pump(const Duration(seconds: 1));
      await logout(tester);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets(
    'client GUI server pagination and related-article navigation',
    (tester) async {
      await start(tester);
      await login(tester, config['clientEmail'] as String);
      await drawer(tester, 'Članci');
      await wait(tester, find.byType(ArticlePagination));
      await tap(tester, find.byKey(const ValueKey('article-page-2')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('article-page-2')), findsOneWidget);
      await tap(tester, find.text('Read article').first);
      await wait(tester, find.byType(ArticleDetailsPage));
      final original = tester
          .widget<ArticleDetailsPage>(find.byType(ArticleDetailsPage))
          .articleId;
      final related = find.byWidgetPredicate(
        (w) => w.key.toString().contains('related-article-'),
      );
      await tap(tester, related);
      await tester.pump(const Duration(seconds: 1));
      final opened = tester
          .widget<ArticleDetailsPage>(find.byType(ArticleDetailsPage))
          .articleId;
      expect(opened, isNot(original));
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ArticlePagination), findsOneWidget);
      evidence['blogGui'] = {
        'serverPage': 2,
        'originalArticle': original,
        'relatedArticle': opened,
        'backToList': true,
      };
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      await logout(tester);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
