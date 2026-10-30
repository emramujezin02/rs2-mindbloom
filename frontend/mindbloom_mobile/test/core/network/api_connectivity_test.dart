import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindbloom_mobile/core/constants/api_constants.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/features/auth/data/models/login_request.dart';
import 'package:mindbloom_mobile/features/auth/data/services/auth_api_service.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

class _EmptySession extends SessionStorageService {
  @override
  Future<String?> getToken() async => null;
}

void main() {
  const override = String.fromEnvironment('API_BASE_URL');
  final expected = override.isEmpty
      ? Uri.parse('http://10.0.2.2:5110')
      : Uri.parse(override.trim().replaceFirst(RegExp(r'/$'), ''));

  test(
    'actual API client preserves Debug default or explicit dart-define',
    () async {
      final transport = MockClient((request) async {
        expect(request.url.origin, expected.origin);
        expect(request.url.path, '${expected.path}/api/Articles');
        expect(request.url.queryParameters, {'pageNumber': '2'});
        return http.Response('{"items":[]}', 200);
      });
      addTearDown(transport.close);
      final client = ApiClient(
        sessionStorage: _EmptySession(),
        httpClient: transport,
      );
      await client.get('/Articles?pageNumber=2', requiresAuth: false);
      expect(ApiConstants.apiBaseUrl, '${expected.toString()}/api');
    },
  );

  test(
    'auth transport uses selected API address and keeps login contract',
    () async {
      final transport = MockClient((request) async {
        expect(request.url.origin, expected.origin);
        expect(request.url.path, '${expected.path}/api/Auth/login-2fa');
        expect(request.method, 'POST');
        expect(request.headers.containsKey('Authorization'), false);
        expect(jsonDecode(request.body), {
          'email': 'demo@example.test',
          'password': 'fixture-only',
          'rememberMe': false,
        });
        return http.Response(
          '{"requiresTwoFactor":false,"message":"Success"}',
          200,
        );
      });
      addTearDown(transport.close);
      final auth = AuthApiService(
        apiClient: ApiClient(
          sessionStorage: _EmptySession(),
          httpClient: transport,
        ),
      );
      final response = await auth.login(
        LoginRequest(
          email: 'demo@example.test',
          password: 'fixture-only',
          rememberMe: false,
        ),
      );
      expect(response.requiresTwoFactor, false);
      expect(response.message, 'Success');
    },
  );

  test(
    'Release policy permits only emulator cleartext and keeps TLS defaults',
    () {
      final policy = File(
        'android/app/src/release/res/xml/network_security_config.xml',
      ).readAsStringSync();
      expect(
        policy,
        contains('<base-config cleartextTrafficPermitted="false"'),
      );
      expect(
        policy,
        contains('<domain-config cleartextTrafficPermitted="true"'),
      );
      final domains = RegExp(
        r'<domain\s+includeSubdomains="false">([^<]+)</domain>',
      ).allMatches(policy).map((m) => m.group(1)).toList();
      expect(domains, ['10.0.2.2']);
      expect(policy, isNot(contains('trust-anchors')));
      expect(policy, isNot(contains('debug-overrides')));
    },
  );

  test('Release manifest references policy and main includes INTERNET', () {
    final main = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final release = File(
      'android/app/src/release/AndroidManifest.xml',
    ).readAsStringSync();
    expect(main, contains('android.permission.INTERNET'));
    expect(
      release,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    expect(release, contains('android:usesCleartextTraffic="false"'));
  });

  for (final variant in ['debug', 'profile']) {
    test(
      '$variant keeps its existing HTTP support independent of Release policy',
      () {
        final manifest = File(
          'android/app/src/$variant/AndroidManifest.xml',
        ).readAsStringSync();
        expect(manifest, contains('android:usesCleartextTraffic="true"'));
        expect(manifest, isNot(contains('networkSecurityConfig')));
      },
    );
  }
}
