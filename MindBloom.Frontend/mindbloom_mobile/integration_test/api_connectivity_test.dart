import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mindbloom_mobile/core/constants/api_constants.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile ApiClient reaches MindBloom API', (_) async {
    final client = ApiClient(sessionStorage: SessionStorageService());

    final response = await client.get(
      '/privacy/current-versions',
      requiresAuth: false,
    );

    expect(ApiConstants.baseUrl, isNot(contains(':8080')));
    expect(response, isA<Map<String, dynamic>>());
    expect(response['privacyPolicyVersion'], isNotNull);
    expect(response['termsOfServiceVersion'], isNotNull);
  });
}
