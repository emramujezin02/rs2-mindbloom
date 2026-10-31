import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 10),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final output = Platform.environment['MINDBLOOM_QA_OUTPUT'];
    if (output == null || !Directory(output).existsSync()) {
      throw StateError(
        'An existing external QA evidence directory is required.',
      );
    }
    await File(
      '$output/android-gui-evidence.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  },
);
