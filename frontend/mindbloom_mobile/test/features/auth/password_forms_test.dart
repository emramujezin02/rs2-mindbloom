import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/app/router/app_router.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/core/validation/app_validators.dart';
import 'package:mindbloom_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:mindbloom_mobile/features/auth/data/services/auth_api_service.dart';
import 'package:mindbloom_mobile/features/auth/presentation/pages/change_password_page.dart';
import 'package:mindbloom_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:mindbloom_mobile/features/auth/presentation/pages/register_page.dart';
import 'package:mindbloom_mobile/features/auth/presentation/pages/reset_password_page.dart';
import 'package:mindbloom_mobile/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  testWidgets('login continues to accept a short existing password', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.enterText(_field('Email'), 'test@example.com');
    await tester.enterText(_field('Password'), 'old');
    expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
  });

  testWidgets(
    'registration retains loading state and disables duplicate submission',
    (tester) async {
      final response = Completer<Map<String, dynamic>>();
      addTearDown(() {
        if (!response.isCompleted) response.complete({});
      });
      final client = _RegistrationApiClient(pendingResponse: response.future);
      await _registration(tester, client, 'Lozinka1!');
      final button = find.byType(ElevatedButton);
      await _show(tester, button);
      await tester.tap(button);
      await tester.pump();
      expect(client.registrations, hasLength(1));
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      expect(tester.widget<TextFormField>(_field('Password')).enabled, isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      response.complete({});
      await tester.pumpAndSettle();
      expect(find.text('Verification destination'), findsOneWidget);
    },
  );

  testWidgets('registration rejects weak password before calling API', (
    tester,
  ) async {
    final client = _RegistrationApiClient();
    await _registration(tester, client, 'lozinka1');
    await _submit(tester);
    expect(
      find.text(AppValidators.passwordRequirementsMessage),
      findsOneWidget,
    );
    expect(client.registrations, isEmpty);
    final field = tester.widget<TextField>(
      find.descendant(of: _field('Password'), matching: find.byType(TextField)),
    );
    expect(field.decoration!.errorMaxLines, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid registration sends unchanged password and navigates', (
    tester,
  ) async {
    final client = _RegistrationApiClient();
    await _registration(tester, client, 'Lozinka1!');
    await _submit(tester);
    expect(client.registrations, hasLength(1));
    expect(client.registrations.single['password'], 'Lozinka1!');
    expect(find.text('Verification destination'), findsOneWidget);
  });

  testWidgets('correcting weak password permits a subsequent registration', (
    tester,
  ) async {
    final client = _RegistrationApiClient();
    await _registration(tester, client, 'Lozinka1');
    await _submit(tester);
    expect(client.registrations, isEmpty);
    await _show(tester, _field('Password'));
    await tester.enterText(_field('Password'), 'Test1234@');
    await _submit(tester);
    expect(client.registrations, hasLength(1));
    expect(find.text('Verification destination'), findsOneWidget);
  });

  testWidgets('registration retains API error handling', (tester) async {
    final client = _RegistrationApiClient(failRegistration: true);
    await _registration(tester, client, 'Sigurna#2026');
    await _submit(tester);
    expect(client.registrations, hasLength(1));
    expect(find.text('Registration could not be completed'), findsOneWidget);
    expect(find.byType(RegisterPage), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('registration password visibility preserves its value', (
    tester,
  ) async {
    final client = _RegistrationApiClient();
    await _registration(tester, client, 'Abcdef1!');
    await _show(tester, _field('Password'));
    final input = find.descendant(
      of: _field('Password'),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(input).obscureText, isTrue);
    await tester.tap(
      find.descendant(
        of: _field('Password'),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pump();
    expect(tester.widget<TextField>(input).obscureText, isFalse);
    expect(tester.widget<TextField>(input).controller!.text, 'Abcdef1!');
    expect(client.registrations, isEmpty);
  });

  testWidgets(
    'reset uses shared rules and rechecks confirmation after editing password',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ResetPasswordPage(email: 'test@example.com')),
      );
      await tester.enterText(_field('Reset code'), '123456');
      await tester.enterText(_field('New password'), 'lozinka1');
      await tester.enterText(_field('Confirm password'), 'lozinka1');
      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(
        find.text(AppValidators.passwordRequirementsMessage),
        findsOneWidget,
      );
      await tester.enterText(_field('New password'), 'Lozinka1!');
      await tester.enterText(_field('Confirm password'), 'Lozinka1!');
      expect(form.validate(), isTrue);
      await tester.enterText(_field('New password'), 'Test1234@');
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
    },
  );

  testWidgets(
    'change validates new password without restricting current password',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChangePasswordPage()));
      await tester.enterText(_field('Current password'), 'old');
      await tester.enterText(_field('New password'), 'lozinka1');
      await tester.enterText(_field('Confirm new password'), 'lozinka1');
      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(
        find.text(AppValidators.passwordRequirementsMessage),
        findsOneWidget,
      );
      await tester.enterText(_field('New password'), 'Lozinka1!');
      await tester.enterText(_field('Confirm new password'), 'Lozinka1!');
      expect(form.validate(), isTrue);
      await tester.enterText(_field('New password'), 'Test1234@');
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.enterText(_field('Current password'), 'Test1234@');
      await tester.enterText(_field('Confirm new password'), 'Test1234@');
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(
        find.text('New password must be different from the current password.'),
        findsOneWidget,
      );
    },
  );
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _registration(
  WidgetTester tester,
  _RegistrationApiClient client,
  String password,
) async {
  final viewModel = AuthViewModel(
    authRepository: AuthRepository(
      authApiService: AuthApiService(apiClient: client),
      sessionStorage: client.sessionStorage,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: RegisterPage(viewModel: viewModel),
      routes: {
        AppRouter.verifyEmail: (_) =>
            const Scaffold(body: Text('Verification destination')),
      },
    ),
  );
  await tester.pumpAndSettle();
  for (final entry in {
    'First name': 'Test',
    'Last name': 'User',
    'Username': 'testuser',
    'Email': 'test@example.com',
    'Password': password,
  }.entries) {
    await _show(tester, _field(entry.key));
    await tester.enterText(_field(entry.key), entry.value);
  }
  await _show(tester, find.text('Choose date of birth'));
  await tester.tap(find.text('Choose date of birth'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  for (var index = 0; index < 2; index++) {
    final checkbox = find.byType(CheckboxListTile).at(index);
    await _show(tester, checkbox);
    await tester.tap(checkbox);
    await tester.pump();
  }
}

Future<void> _submit(WidgetTester tester) async {
  final button = find.byType(ElevatedButton);
  await _show(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

class _RegistrationApiClient extends ApiClient {
  final bool failRegistration;
  final Future<Map<String, dynamic>>? pendingResponse;
  final registrations = <Map<String, dynamic>>[];

  _RegistrationApiClient({this.failRegistration = false, this.pendingResponse})
    : super(sessionStorage: SessionStorageService());

  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    expect(endpoint, '/privacy/current-versions');
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
    expect(endpoint, '/Auth/register');
    registrations.add(Map<String, dynamic>.from(body! as Map));
    if (failRegistration) throw StateError('Test registration failure');
    if (pendingResponse != null) return pendingResponse;
    return <String, dynamic>{};
  }
}
