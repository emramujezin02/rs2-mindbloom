import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Release APKs target the Docker API; local debug runs keep their launch profile.
    defaultValue: kReleaseMode
        ? 'http://10.0.2.2:8080'
        : 'http://10.0.2.2:5110',
  );

  static const String apiPrefix = '/api';

  static String get baseUrl {
    final trimmed = _configuredBaseUrl.trim();

    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }

    return trimmed;
  }

  static String get apiBaseUrl => '$baseUrl$apiPrefix';
}
