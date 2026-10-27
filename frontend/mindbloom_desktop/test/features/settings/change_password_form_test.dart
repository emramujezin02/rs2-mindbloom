import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_desktop/app/router/app_router.dart';
import 'package:mindbloom_desktop/core/error/app_exception.dart';
import 'package:mindbloom_desktop/core/network/api_client.dart';
import 'package:mindbloom_desktop/core/validation/app_validators.dart';
import 'package:mindbloom_desktop/features/auth/data/repositories/auth_repository.dart';
import 'package:mindbloom_desktop/features/auth/data/services/auth_api_service.dart';
import 'package:mindbloom_desktop/features/session/presentation/viewmodels/session_scope.dart';
import 'package:mindbloom_desktop/features/session/presentation/viewmodels/session_viewmodel.dart';
import 'package:mindbloom_desktop/features/settings/data/models/admin_application_info_model.dart';
import 'package:mindbloom_desktop/features/settings/data/repositories/admin_settings_repository.dart';
import 'package:mindbloom_desktop/features/settings/data/services/admin_settings_api_service.dart';
import 'package:mindbloom_desktop/features/settings/presentation/pages/settings_page.dart';
import 'package:mindbloom_desktop/features/settings/presentation/viewmodels/admin_settings_viewmodel.dart';
import 'package:mindbloom_desktop/services/session_storage_service.dart';

void main() {
  for (final scenario in [
    'weak',
    'mismatch',
    'missing current',
    'same password',
  ]) {
    testWidgets('$scenario does not send a password change request', (
      tester,
    ) async {
      final api = _Api();
      await _page(tester, api);
      await _fill(
        tester,
        current: scenario == 'missing current' ? '' : 'Previous123!',
        password: scenario == 'weak'
            ? 'lozinka1'
            : scenario == 'same password'
            ? 'Previous123!'
            : 'Updated123!',
        confirmation: scenario == 'mismatch'
            ? 'Different123!'
            : scenario == 'weak'
            ? 'lozinka1'
            : scenario == 'same password'
            ? 'Previous123!'
            : 'Updated123!',
      );
      await _show(tester, find.text('Promijeni lozinku'));
      await tester.tap(find.text('Promijeni lozinku'));
      await tester.pumpAndSettle();
      expect(api.requests, isEmpty);
      if (scenario == 'weak') {
        expect(
          find.text(AppValidators.passwordRequirementsMessage),
          findsOneWidget,
        );
      }
      if (scenario == 'mismatch') {
        expect(find.text('Lozinke se ne podudaraju.'), findsOneWidget);
      }
    });
  }

  testWidgets(
    'successful change forwards all fields clears form and retains logout flow',
    (tester) async {
      final api = _Api();
      final session = await _page(tester, api);
      await _fill(tester);
      await _show(tester, find.text('Promijeni lozinku'));
      await tester.tap(find.text('Promijeni lozinku'));
      await tester.pumpAndSettle();
      expect(api.requests.single, {
        'currentPassword': 'Previous123!',
        'newPassword': 'Updated123!',
        'confirmNewPassword': 'Updated123!',
      });
      expect(find.text('Lozinka je promijenjena'), findsOneWidget);
      for (final label in [
        'Trenutna lozinka',
        'Nova lozinka',
        'Potvrdi novu lozinku',
      ]) {
        final field = tester.widget<TextField>(
          find.descendant(
            of: _field(label),
            matching: find.byType(TextField),
            skipOffstage: false,
          ),
        );
        expect(field.controller!.text, isEmpty);
      }
      await tester.tap(find.text('U redu'));
      await tester.pumpAndSettle();
      expect(session.logouts, 1);
      expect(find.text('Login destination'), findsOneWidget);
    },
  );

  testWidgets(
    'backend validation error is displayed without clearing input or logging out',
    (tester) async {
      final api = _Api(fail: true);
      final session = await _page(tester, api);
      await _fill(tester);
      await _show(tester, find.text('Promijeni lozinku'));
      await tester.tap(find.text('Promijeni lozinku'));
      await tester.pumpAndSettle();
      expect(api.requests, hasLength(1));
      expect(
        find.textContaining('Confirmation does not match.'),
        findsOneWidget,
      );
      expect(session.logouts, 0);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: _field('Nova lozinka'),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        'Updated123!',
      );
    },
  );

  testWidgets('loading disables a second submission and resets after failure', (
    tester,
  ) async {
    final pending = Completer<void>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete();
    });
    final api = _Api(pending: pending.future, fail: true);
    await _page(tester, api);
    await _fill(tester);
    final button = find.widgetWithText(FilledButton, 'Promijeni lozinku');
    await _show(tester, button);
    await tester.tap(button);
    await tester.pump();
    expect(api.requests, hasLength(1));
    expect(
      tester.widget<TextFormField>(_field('Nova lozinka')).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Promjena...'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(_field('Nova lozinka')).enabled,
      isTrue,
    );
    expect(api.requests, hasLength(1));
  });
}

Finder _field(String label) =>
    find.widgetWithText(TextFormField, label, skipOffstage: false);

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  String current = 'Previous123!',
  String password = 'Updated123!',
  String confirmation = 'Updated123!',
}) async {
  for (final entry in {
    'Trenutna lozinka': current,
    'Nova lozinka': password,
    'Potvrdi novu lozinku': confirmation,
  }.entries) {
    await _show(tester, _field(entry.key));
    await tester.enterText(_field(entry.key), entry.value);
  }
}

Future<_Session> _page(WidgetTester tester, _Api api) async {
  final session = _Session(api);
  addTearDown(session.dispose);
  final viewModel = AdminSettingsViewModel(
    repository: _Repository(AdminSettingsApiService(apiClient: api)),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: SessionScope(
        session: session,
        child: Scaffold(body: SettingsPage(viewModel: viewModel)),
      ),
      routes: {
        AppRouter.login: (_) => const Scaffold(body: Text('Login destination')),
      },
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

class _Repository extends AdminSettingsRepository {
  _Repository(AdminSettingsApiService service) : super(apiService: service);
  @override
  Future<AdminApplicationInfoModel> getApplicationInfo() async =>
      const AdminApplicationInfoModel(
        version: 'test',
        buildNumber: '1',
        environment: 'Testing',
      );
}

class _Session extends SessionViewModel {
  int logouts = 0;
  _Session(_Api api)
    : super(
        sessionStorage: api.sessionStorage,
        authRepository: AuthRepository(
          apiService: AuthApiService(apiClient: api),
          sessionStorage: api.sessionStorage,
        ),
      );
  @override
  Future<void> logout() async {
    logouts++;
  }
}

class _Api extends ApiClient {
  final bool fail;
  final Future<void>? pending;
  final requests = <Map<String, dynamic>>[];
  _Api({this.fail = false, this.pending})
    : super(sessionStorage: SessionStorageService());

  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    if (endpoint == '/Users/me') {
      return <String, dynamic>{
        'firstName': 'Test',
        'lastName': 'Admin',
        'email': 'test@example.com',
        'dateOfBirth': '1990-01-01',
      };
    }
    expect(endpoint, '/user-settings/me');
    return <String, dynamic>{
      'notificationsEnabled': true,
      'showProfilePublicly': true,
    };
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    expect(endpoint, '/Auth/change-password');
    expect(requiresAuth, isTrue);
    requests.add(Map<String, dynamic>.from(body! as Map));
    if (pending != null) await pending;
    if (fail) {
      throw AppException(
        message: 'Confirmation does not match.',
        statusCode: 400,
        validationErrors: {
          'ConfirmNewPassword': ['Confirmation does not match.'],
        },
      );
    }
    return <String, dynamic>{'message': 'Password changed successfully.'};
  }
}
