import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindbloom_mobile/app/router/app_router.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/core/error/app_exception.dart';
import 'package:mindbloom_mobile/core/validation/app_validators.dart';
import 'package:mindbloom_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:mindbloom_mobile/features/auth/data/services/auth_api_service.dart';
import 'package:mindbloom_mobile/features/auth/data/models/register_request.dart';
import 'package:mindbloom_mobile/features/auth/data/models/register_therapist_request.dart';
import 'package:mindbloom_mobile/features/auth/presentation/pages/register_page.dart';
import 'package:mindbloom_mobile/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:mindbloom_mobile/features/therapist/data/services/therapist_api_service.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  for (final role in [null, 'therapist', 'Therapist', 'unknown', 42]) {
    testWidgets('registration route handles initialRole $role safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final route =
                  AppRouter.generateRoute(
                        RouteSettings(
                          name: AppRouter.register,
                          arguments: {'initialRole': role},
                        ),
                      )
                      as MaterialPageRoute;
              final page = route.builder(context) as RegisterPage;
              expect(
                page.initialRole,
                role is String && role.toLowerCase() == 'therapist'
                    ? 'Therapist'
                    : 'Client',
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });
  }

  testWidgets(
    'default client can select therapist and hide unvalidated professional fields again',
    (tester) async {
      final api = _Api();
      await _page(tester, api);
      expect(find.text('Klijent'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Biografija'), findsNothing);
      await _role(tester, 'Psihoterapeut');
      expect(find.widgetWithText(TextFormField, 'Biografija'), findsOneWidget);
      expect(api.lookups, 1);
      await _role(tester, 'Klijent');
      expect(find.widgetWithText(TextFormField, 'Biografija'), findsNothing);
      await _fillAccount(tester);
      await _submit(tester);
      expect(api.calls.single.$1, '/Auth/register');
      expect(api.calls.single.$2['gender'], 'Other');
      expect(api.calls.single.$2.containsKey('specialization'), isFalse);
    },
  );

  testWidgets(
    'therapist initial role sends all fields to therapist endpoint and continues to email verification',
    (tester) async {
      final api = _Api();
      await _page(tester, api, role: 'Therapist');
      expect(find.text('Psihoterapeut'), findsOneWidget);
      await _fillAccount(tester);
      await _fillProfessional(tester);
      await _submit(tester);
      final (endpoint, body) = api.calls.single;
      expect(endpoint, '/Auth/register-therapist');
      expect(body.keys.toSet(), {
        'locationId',
        'worksWithChildren',
        'firstName',
        'lastName',
        'username',
        'email',
        'password',
        'gender',
        'dateOfBirth',
        'acceptPrivacyPolicy',
        'privacyPolicyVersion',
        'acceptTermsOfService',
        'termsOfServiceVersion',
        'specialization',
        'biography',
        'country',
        'city',
        'address',
        'hourlyRate',
        'experienceYears',
        'offersOnline',
        'offersInPerson',
      });
      expect(body['specialization'], 'Psychotherapy');
      expect(body['locationId'], 42);
      expect(body['country'], 'Test');
      expect(body['city'], 'Test city');
      expect(body['worksWithChildren'], isTrue);
      expect(body['hourlyRate'], 50.5);
      expect(body['experienceYears'], 5);
      expect(body['offersOnline'], isTrue);
      expect(body['offersInPerson'], isFalse);
      expect(find.text('Verify email destination'), findsOneWidget);
    },
  );

  testWidgets(
    'invalid therapist password and missing professional fields cannot send request',
    (tester) async {
      final api = _Api();
      await _page(tester, api, role: 'Therapist');
      await _fillAccount(tester, password: 'lozinka1');
      await _submit(tester);
      expect(api.calls, isEmpty);
      expect(
        find.text(AppValidators.passwordRequirementsMessage),
        findsOneWidget,
      );
      await _enter(tester, 'Password', 'Lozinka1!');
      await _submit(tester);
      expect(api.calls, isEmpty);
      expect(find.text('Odaberite specijalizaciju.'), findsOneWidget);
    },
  );

  testWidgets(
    'backend validation errors remain visible on therapist registration',
    (tester) async {
      final api = _Api(fail: true);
      await _page(tester, api, role: 'Therapist');
      await _fillAccount(tester);
      await _fillProfessional(tester);
      await _submit(tester);
      expect(api.calls, hasLength(1));
      expect(find.textContaining('Email already exists.'), findsWidgets);
      expect(find.byType(RegisterPage), findsOneWidget);
    },
  );

  testWidgets(
    'therapist registration disables duplicate submission while loading',
    (tester) async {
      final pending = Completer<void>();
      addTearDown(() {
        if (!pending.isCompleted) pending.complete();
      });
      final api = _Api(pending: pending.future);
      await _page(tester, api, role: 'Therapist');
      await _fillAccount(tester);
      await _fillProfessional(tester);
      await _show(tester, find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(api.calls, hasLength(1));
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(api.calls, hasLength(1));
    },
  );

  test(
    'real API client serializes therapist DTO and multipart with token and MIME type',
    () async {
      final requests = <http.Request>[];
      final storage = _Storage();
      final api = ApiClient(
        sessionStorage: storage,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('register-therapist')) {
            return http.Response(
              jsonEncode({
                'userId': 1,
                'therapistId': 2,
                'email': 'test@example.com',
                'verificationStatus': 'Pending',
                'message': 'Pending verification',
              }),
              201,
            );
          }
          return http.Response(
            '{"message":"Document uploaded successfully."}',
            200,
          );
        }),
      );
      final result = await AuthApiService(apiClient: api).registerTherapist(
        RegisterTherapistRequest(
          account: RegisterRequest(
            firstName: 'Test',
            lastName: 'User',
            username: 'testuser',
            email: 'test@example.com',
            password: 'Lozinka1!',
            dateOfBirth: DateTime(1990),
            gender: 'Female',
            acceptPrivacyPolicy: true,
            privacyPolicyVersion: 'test-v1',
            acceptTermsOfService: true,
            termsOfServiceVersion: 'test-v1',
          ),
          details: const TherapistRegistrationDetails(
            specialization: 'Psychotherapy',
            biography: 'Biography',
            country: 'Test',
            city: 'Test',
            address: 'Test',
            hourlyRate: 50,
            experienceYears: 5,
            offersOnline: true,
            offersInPerson: false,
          ),
        ),
      );
      expect(result.verificationStatus, 'Pending');
      expect(requests.first.url.path, '/api/Auth/register-therapist');
      expect((jsonDecode(requests.first.body) as Map)['gender'], 'Female');
      final folder = await Directory.systemTemp.createTemp(
        'mindbloom-synthetic-document-',
      );
      try {
        final file = await File(
          '${folder.path}/synthetic.pdf',
        ).writeAsString('%PDF-1.4 synthetic');
        await TherapistApiService(
          apiClient: api,
        ).uploadVerificationDocument(file.path, 'application/pdf');
        final request = requests.last;
        expect(request.url.path, '/api/Therapists/documents');
        expect(request.url.query, isEmpty);
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(
          request.headers['Content-Type'],
          startsWith('multipart/form-data; boundary='),
        );
        expect(request.body, contains('name="File"'));
        expect(
          request.body.toLowerCase(),
          contains('content-type: application/pdf'),
        );
        expect(request.body, contains('%PDF-1.4 synthetic'));
        expect(request.body, isNot(contains('TherapistId')));
      } finally {
        await File('${folder.path}/synthetic.pdf').delete();
        await folder.delete();
      }
      expect(storage.saved, isFalse);
    },
  );
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);
Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  await _show(tester, _field(label));
  await tester.enterText(_field(label), value);
}

Future<void> _role(WidgetTester tester, String label) async {
  final dropdown = find.byKey(const ValueKey('registration-role'));
  await _show(tester, dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _page(
  WidgetTester tester,
  _Api api, {
  String role = 'Client',
}) async {
  final model = AuthViewModel(
    authRepository: AuthRepository(
      authApiService: AuthApiService(apiClient: api),
      sessionStorage: api.sessionStorage,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: RegisterPage(viewModel: model, initialRole: role),
      routes: {
        AppRouter.verifyEmail: (_) =>
            const Scaffold(body: Text('Verify email destination')),
      },
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillAccount(
  WidgetTester tester, {
  String password = 'Lozinka1!',
}) async {
  for (final entry in {
    'First name': 'Test',
    'Last name': 'User',
    'Username': 'testuser',
    'Email': 'test@example.com',
    'Password': password,
  }.entries) {
    await _enter(tester, entry.key, entry.value);
  }
  await _show(tester, find.text('Choose date of birth'));
  await tester.tap(find.text('Choose date of birth'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  for (final title in [
    'I accept the Privacy Policy',
    'I accept the Terms of Service',
  ]) {
    await _show(tester, find.text(title));
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }
}

Future<void> _fillProfessional(WidgetTester tester) async {
  final specialization = find.widgetWithText(
    DropdownButtonFormField<String>,
    'Specijalizacija',
  );
  await _show(tester, specialization);
  await tester.tap(specialization);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Psychotherapy').last);
  await tester.pumpAndSettle();
  for (final entry in {
    'Biografija': 'Test biography',
    'Cijena termina (KM)': '50,5',
    'Godine iskustva': '5',
    'Adresa': 'Test',
  }.entries) {
    await _enter(tester, entry.key, entry.value);
  }
  final location = find.widgetWithText(
    DropdownButtonFormField<int>,
    'Lokacija',
  );
  await _show(tester, location);
  await tester.tap(location);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test city, Test region, Test').last);
  await tester.pumpAndSettle();
  await _show(tester, find.text('Radim s djecom'));
  await tester.tap(find.text('Radim s djecom'));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await _show(tester, find.byType(ElevatedButton));
  await _show(tester, find.byType(ElevatedButton));
  expect(find.byType(ElevatedButton).hitTestable(), findsOneWidget);
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
}

class _Api extends ApiClient {
  final bool fail;
  final Future<void>? pending;
  int lookups = 0;
  final calls = <(String, Map<String, dynamic>)>[];
  _Api({this.fail = false, this.pending}) : super(sessionStorage: _Storage());
  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    if (endpoint.contains('/locations/active')) {
      return {
        'items': [
          {
            'id': 42,
            'name': 'Test city',
            'country': 'Test',
            'region': 'Test region',
            'isActive': true,
          },
        ],
        'pageNumber': 1,
        'pageSize': 50,
        'totalCount': 1,
        'totalPages': 1,
        'hasNextPage': false,
      };
    }
    if (endpoint.contains('specializations')) {
      lookups++;
      return <dynamic>[
        {'name': 'Psychotherapy'},
      ];
    }
    return <String, dynamic>{
      'privacyPolicyVersion': 'test-v1',
      'termsOfServiceVersion': 'test-v1',
    };
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
    String? idempotencyKey,
  }) async {
    calls.add((endpoint, Map<String, dynamic>.from(body! as Map)));
    expect(requiresAuth, isFalse);
    if (pending != null) await pending;
    if (fail) {
      throw const AppException(
        message: 'Email already exists.',
        statusCode: 400,
        fieldErrors: {
          'Email': ['Email already exists.'],
        },
      );
    }
    return <String, dynamic>{
      'userId': 1,
      'therapistId': 2,
      'email': 'test@example.com',
      'verificationStatus': 'Pending',
      'message': 'Pending verification',
    };
  }
}

class _Storage extends SessionStorageService {
  bool saved = false;
  @override
  Future<String?> getToken() async => 'test-token';
  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    saved = true;
  }
}
