import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindbloom_desktop/core/error/app_exception.dart';
import 'package:mindbloom_desktop/core/network/api_client.dart';
import 'package:mindbloom_desktop/features/therapist_verification/data/services/therapist_verification_api_service.dart';
import 'package:mindbloom_desktop/features/therapist_verification/data/repositories/therapist_verification_repository.dart';
import 'package:mindbloom_desktop/features/therapist_verification/presentation/viewmodels/therapist_verification_details_viewmodel.dart';
import 'package:mindbloom_desktop/services/session_storage_service.dart';

void main() {
  test(
    'private document download uses authenticated endpoint and preserves binary bytes',
    () async {
      await http.runWithClient(
        () async {
          final model = _model(_Storage());
          addTearDown(model.dispose);
          expect(await model.downloadDocument(42), [
            37,
            80,
            68,
            70,
            45,
            255,
            0,
            128,
          ]);
        },
        () => MockClient((request) async {
          expect(request.url.path, '/api/Therapists/documents/42/download');
          expect(request.url.query, isEmpty);
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response.bytes(
            [37, 80, 68, 70, 45, 255, 0, 128],
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }),
      );
    },
  );

  test(
    'download does not interpret an authorization error as file bytes',
    () async {
      await http.runWithClient(
        () async {
          final model = _model(_Storage());
          addTearDown(model.dispose);
          await expectLater(
            model.downloadDocument(42),
            throwsA(
              isA<AppException>().having(
                (error) => error.statusCode,
                'status',
                403,
              ),
            ),
          );
        },
        () => MockClient(
          (_) async => http.Response('{"message":"Forbidden"}', 403),
        ),
      );
    },
  );

  test(
    'binary download retains existing token refresh and request retry behavior',
    () async {
      final storage = _Storage();
      var downloads = 0;
      await http.runWithClient(
        () async {
          final model = _model(storage);
          addTearDown(model.dispose);
          expect(await model.downloadDocument(42), [255, 0, 128]);
        },
        () => MockClient((request) async {
          if (request.url.path == '/api/Auth/refresh-token') {
            expect(request.method, 'POST');
            return http.Response(
              jsonEncode({
                'token': 'refreshed-test-token',
                'refreshToken': 'test-refresh-new',
                'role': 'Admin',
              }),
              200,
            );
          }
          downloads++;
          if (downloads == 1) return http.Response('', 401);
          expect(
            request.headers['Authorization'],
            'Bearer refreshed-test-token',
          );
          return http.Response.bytes([255, 0, 128], 200);
        }),
      );
      expect(downloads, 2);
      expect(storage.token, 'refreshed-test-token');
    },
  );
}

TherapistVerificationDetailsViewModel _model(_Storage storage) =>
    TherapistVerificationDetailsViewModel(
      repository: TherapistVerificationRepository(
        apiService: TherapistVerificationApiService(
          apiClient: ApiClient(sessionStorage: storage),
        ),
      ),
    );

class _Storage extends SessionStorageService {
  String token = 'test-token';
  @override
  Future<String?> getAccessToken() async => token;
  @override
  Future<String?> getRefreshToken() async => 'test-refresh';
  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String role,
  }) async {
    token = accessToken;
  }
}
