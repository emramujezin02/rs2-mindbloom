import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/app/router/app_router.dart';
import 'package:mindbloom_mobile/features/auth/presentation/pages/login_page.dart';

void main() {
  Widget createTestApp() {
    return MaterialApp(
      home: const LoginPage(),
      routes: {
        AppRouter.forgotPassword: (_) => const Scaffold(
          body: Center(child: Text('Forgot Password Test Page')),
        ),
        AppRouter.register: (_) =>
            const Scaffold(body: Center(child: Text('Register Test Page'))),
      },
    );
  }

  group('LoginPage', () {
    testWidgets('shows login form', (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.text('Welcome to MindBloom'), findsOneWidget);

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);

      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);

      expect(find.text('Remember me'), findsOneWidget);

      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });

    testWidgets('shows required validation errors when form is empty', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));

      await tester.pump();

      expect(find.text('Email is required.'), findsOneWidget);

      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('shows invalid email validation error', (tester) async {
      await tester.pumpWidget(createTestApp());

      final fields = find.byType(TextFormField);

      expect(fields, findsNWidgets(2));

      await tester.enterText(fields.at(0), 'invalid-email');

      await tester.enterText(fields.at(1), 'Password123!');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));

      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('remember me checkbox can be changed', (tester) async {
      await tester.pumpWidget(createTestApp());

      Checkbox checkbox = tester.widget<Checkbox>(find.byType(Checkbox));

      expect(checkbox.value, isFalse);

      await tester.tap(find.text('Remember me'));

      await tester.pump();

      checkbox = tester.widget<Checkbox>(find.byType(Checkbox));

      expect(checkbox.value, isTrue);
    });

    testWidgets('forgot password navigates to forgot password route', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());

      await tester.tap(find.text('Forgot password?'));

      await tester.pumpAndSettle();

      expect(find.text('Forgot Password Test Page'), findsOneWidget);
    });

    testWidgets('register button navigates to register route', (tester) async {
      await tester.pumpWidget(createTestApp());

      await tester.tap(find.text('Do not have an account? Register'));

      await tester.pumpAndSettle();

      expect(find.text('Register Test Page'), findsOneWidget);
    });
  });
}
