import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:mindbloom_mobile/core/constants/api_constants.dart';
import 'package:mindbloom_mobile/main.dart' as application;

// Real Android registration and native document picker. The external email
// transport is captured by the isolated host; the actual verification endpoint
// and all production forms/services remain in use.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'therapist Android registration, email verification and private document upload',
    (tester) async {
      expect(ApiConstants.baseUrl, 'http://10.0.2.2:8082');
      final config =
          jsonDecode(
                await File(
                  '/data/user/0/com.example.mindbloom_mobile/files/qa-config.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final email = 'registered-${config['runId']}@test.local';
      Future<void> wait(Finder target, {int seconds = 60}) async {
        final until = DateTime.now().add(Duration(seconds: seconds));
        while (target.evaluate().isEmpty && DateTime.now().isBefore(until)) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(target, findsWidgets, reason: 'Expected GUI target: $target');
      }

      Future<void> tap(Finder target) async {
        await wait(target);
        await tester.ensureVisible(target.first);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(target.first);
        await tester.pump(const Duration(milliseconds: 500));
      }

      Future<void> enter(String label, String value) async {
        final field = find.widgetWithText(TextFormField, label);
        await wait(field);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      final handler = FlutterError.onError;
      await application.main();
      FlutterError.onError = handler;
      await tester.pump(const Duration(seconds: 2));
      await tap(find.text('Do not have an account? Register'));
      await tap(find.text('Klijent'));
      await tap(find.text('Psihoterapeut').last);
      await tap(find.widgetWithText(ElevatedButton, 'Register'));
      expect(find.text('First name is required.'), findsOneWidget);
      await enter('First name', 'QA');
      await enter('Last name', 'Registrant');
      await enter('Username', 'qa_reg_${config['runId']}');
      await enter('Email', email);
      await enter('Password', 'short');
      await tap(find.widgetWithText(ElevatedButton, 'Register'));
      expect(find.text('Verify email'), findsNothing);
      await enter('Password', config['password'] as String);
      await tap(find.text('Choose date of birth'));
      await tap(find.byTooltip('Switch to input'));
      final dateInput = find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(dateInput, '01/01/1990');
      await tap(find.text('OK'));
      await tap(find.text('Specijalizacija'));
      await tap(find.text('QA Psychotherapy').last);
      await enter(
        'Biografija',
        'Synthetic therapist registration for isolated GUI verification.',
      );
      await enter('Cijena termina (KM)', '80');
      await enter('Godine iskustva', '5');
      await tap(find.text('Odaberite lokaciju'));
      await tap(find.textContaining('Sarajevo').last);
      await enter('Adresa', 'QA address');
      await tap(find.text('I accept the Privacy Policy'));
      await tap(find.text('I accept the Terms of Service'));
      await tap(find.widgetWithText(ElevatedButton, 'Register'));
      await wait(find.text('Verify email'));
      final captured = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/__qa/email-code?email=${Uri.encodeComponent(email)}',
        ),
        headers: {'X-Qa-Key': config['controlKey'] as String},
      );
      expect(captured.statusCode, 200);
      final code =
          (jsonDecode(captured.body) as Map<String, dynamic>)['code'] as String;
      expect(code, matches(RegExp(r'^\d{6}$')));
      await tester.enterText(find.byType(TextFormField), code);
      await tap(find.widgetWithText(ElevatedButton, 'Verify email'));
      await wait(find.widgetWithText(TextFormField, 'Email'));
      await enter('Email', email);
      await enter('Password', config['password'] as String);
      await tap(find.widgetWithText(ElevatedButton, 'Login'));
      await wait(find.byTooltip('Notifikacije'), seconds: 90);
      await tap(find.byTooltip('Open navigation menu'));
      await tap(find.text('Profil'));
      await tap(find.text('Verifikacija i dokumenti'));
      await wait(find.text('Odaberi dokument'));
      await tap(find.text('Odaberi dokument'));
      debugPrint(
        'QA_NATIVE_PICKER_WAIT: select the synthetic qa-verification.pdf from this emulator Downloads.',
      );
      await wait(find.text('qa-verification.pdf'), seconds: 120);
      await tap(find.text('Pošalji dokument'));
      await wait(find.text('Dokument čeka pregled'));
      expect(tester.takeException(), isNull);
      binding.reportData = {
        'registrationGui': true,
        'invalidInputBlocked': true,
        'emailTransport': 'captured test sink; no real email',
        'verification': 'actual endpoint via GUI',
        'document': 'native picker and actual private upload',
        'registeredEmail': email,
        'adminApproval': 'separate Windows GUI phase required',
      };
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
