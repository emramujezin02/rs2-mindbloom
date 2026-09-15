class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String apiPrefix = '/api';

  static String get apiBaseUrl => '$baseUrl$apiPrefix';
}
