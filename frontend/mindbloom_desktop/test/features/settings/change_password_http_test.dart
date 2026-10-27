import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindbloom_desktop/core/error/app_exception.dart';
import 'package:mindbloom_desktop/core/network/api_client.dart';
import 'package:mindbloom_desktop/features/settings/data/services/admin_settings_api_service.dart';
import 'package:mindbloom_desktop/services/session_storage_service.dart';

void main() {
  test(
    'generated HTTP request matches backend JSON route and authentication without logging passwords',
    () async {
      final logs = <String>[];
      var requests = 0;
      await runZoned(
        () async {
          await http.runWithClient(
            () async {
              await AdminSettingsApiService(
                apiClient: ApiClient(sessionStorage: _Storage()),
              ).changePassword(
                currentPassword: 'Previous123!',
                newPassword: 'Updated123!',
                confirmNewPassword: 'Updated123!',
              );
            },
            () => MockClient((request) async {
              requests++;
              expect(request.method, 'POST');
              expect(request.url.path, '/api/Auth/change-password');
              expect(request.url.query, isEmpty);
              expect(request.url.userInfo, isEmpty);
              expect(request.headers['Authorization'], 'Bearer test-token');
              expect(
                request.headers['Content-Type'],
                contains('application/json'),
              );
              expect(jsonDecode(request.body), {
                'currentPassword': 'Previous123!',
                'newPassword': 'Updated123!',
                'confirmNewPassword': 'Updated123!',
              });
              return http.Response(
                '{"message":"Password changed successfully."}',
                200,
              );
            }),
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => logs.add(line),
        ),
      );
      expect(requests, 1);
      expect(logs.join(), isNot(contains('Previous123!')));
      expect(logs.join(), isNot(contains('Updated123!')));
    },
  );

  test(
    'confirmation is forwarded unchanged and HTTP validation error is preserved',
    () async {
      await http.runWithClient(
        () async {
          await expectLater(
            AdminSettingsApiService(
              apiClient: ApiClient(sessionStorage: _Storage()),
            ).changePassword(
              currentPassword: 'Previous123!',
              newPassword: 'Updated123!',
              confirmNewPassword: 'Different123!',
            ),
            throwsA(
              isA<AppException>()
                  .having((error) => error.statusCode, 'status', 400)
                  .having(
                    (error) => error.allValidationMessages,
                    'validation',
                    contains('Confirmation does not match.'),
                  ),
            ),
          );
        },
        () => MockClient((request) async {
          expect(
            (jsonDecode(request.body) as Map)['confirmNewPassword'],
            'Different123!',
          );
          return http.Response(
            jsonEncode({
              'title': 'Validation failed',
              'errors': {
                'ConfirmNewPassword': ['Confirmation does not match.'],
              },
            }),
            400,
          );
        }),
      );
    },
  );
}

class _Storage extends SessionStorageService {
  @override
  Future<String?> getAccessToken() async => 'test-token';
}
