class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5110',
  );

  static const String apiPrefix = '/api';

  static String get apiBaseUrl => '$baseUrl$apiPrefix';
}
