import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mindbloom_desktop/core/constants/api_constants.dart';
import 'package:mindbloom_desktop/main.dart' as application;

// Actual Windows engine, production widgets/repositories and QA HTTP host.
// Only secure storage is replaced with memory so the user's existing desktop
// credentials cannot be read, overwritten or deleted by this test bootstrap.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'isolated administrator GUI login and management navigation',
    (tester) async {
      expect(ApiConstants.baseUrl, 'http://localhost:8082');
      const path = String.fromEnvironment('QA_CONFIG_PATH');
      expect(path, isNotEmpty);
      final config =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      FlutterSecureStorage.setMockInitialValues({});
      application.main();
      Future<void> wait(Finder target) async {
        final until = DateTime.now().add(const Duration(seconds: 60));
        while (target.evaluate().isEmpty && DateTime.now().isBefore(until)) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(target, findsWidgets);
      }

      Future<void> tap(Finder target) async {
        await wait(target);
        await tester.ensureVisible(target.first);
        await tester.tap(target.first);
        await tester.pump(const Duration(milliseconds: 600));
      }

      await wait(find.widgetWithText(TextFormField, 'Email'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        config['adminEmail'] as String,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        config['password'] as String,
      );
      await tap(find.widgetWithText(ElevatedButton, 'Login'));
      await wait(find.text('Dashboard'));
      final visited = <String>[];
      for (final page in [
        'Users',
        'Therapist Verification',
        'Articles',
        'Reference Data',
      ]) {
        await tap(find.text(page).first);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text(page), findsWidgets);
        expect(tester.takeException(), isNull);
        visited.add(page);
      }
      binding.reportData = {
        'actualWindowsGui': true,
        'actualHttpApi': true,
        'storage':
            'test bootstrap memory only; existing desktop credentials untouched',
        'visited': visited,
        'mutations': 'none beyond synthetic QA login',
      };
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
