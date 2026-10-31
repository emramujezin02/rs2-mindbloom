import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mindbloom_mobile/core/constants/api_constants.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile ApiClient reaches MindBloom API', (_) async {
    const configured = String.fromEnvironment('API_BASE_URL');
    final expectedBase = configured.trim().isNotEmpty
        ? configured.trim().replaceFirst(RegExp(r'/$'), '')
        : kReleaseMode
        ? 'http://10.0.2.2:8080'
        : 'http://10.0.2.2:5110';
    expect(ApiConstants.baseUrl, expectedBase);
    expect(ApiConstants.apiBaseUrl, '$expectedBase/api');
    if (configured.trim().isEmpty && kReleaseMode) {
      expect(Uri.parse(ApiConstants.baseUrl).port, 8080);
      expect(Uri.parse(ApiConstants.baseUrl).port, isNot(5110));
    }
    final client = ApiClient(sessionStorage: SessionStorageService());

    final response = await client.get(
      '/privacy/current-versions',
      requiresAuth: false,
    );

    expect(response, isA<Map<String, dynamic>>());
    expect(response['privacyPolicyVersion'], isNotNull);
    expect(response['termsOfServiceVersion'], isNotNull);
  });
}
