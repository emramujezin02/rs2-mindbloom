import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/core/widgets/app_empty_state_widget.dart';
import 'package:mindbloom_mobile/core/widgets/app_error_widget.dart';
import 'package:mindbloom_mobile/core/widgets/app_loading_widget.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('AppLoadingWidget', () {
    testWidgets('shows loading indicator and message', (tester) async {
      await tester.pumpWidget(
        wrap(const AppLoadingWidget(message: 'Loading appointments...')),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      expect(find.text('Loading appointments...'), findsOneWidget);
    });

    testWidgets('shows requested number of skeleton items', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AppLoadingWidget.skeleton(
            message: 'Loading data...',
            skeletonItemCount: 3,
          ),
        ),
      );

      expect(find.byType(Card), findsNWidgets(3));
    });

    testWidgets('load more indicator shows message', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AppLoadMoreIndicator(loadingMessage: 'Loading more results...'),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      expect(find.text('Loading more results...'), findsOneWidget);
    });
  });

  group('AppErrorWidget', () {
    testWidgets('shows error state and retry action', (tester) async {
      var retryCalled = false;

      await tester.pumpWidget(
        wrap(
          AppErrorWidget(
            title: 'Appointments could not be loaded',
            fallbackMessage: 'Something went wrong.',
            onRetry: () async {
              retryCalled = true;
            },
            scrollable: false,
          ),
        ),
      );

      expect(find.text('Appointments could not be loaded'), findsOneWidget);

      expect(find.text('Something went wrong.'), findsOneWidget);

      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));

      await tester.pump();

      expect(retryCalled, isTrue);
    });

    testWidgets('inline error shows retry action', (tester) async {
      var retryCalled = false;

      await tester.pumpWidget(
        wrap(
          AppInlineError(
            title: 'Login failed',
            fallbackMessage: 'Invalid credentials.',
            onRetry: () async {
              retryCalled = true;
            },
          ),
        ),
      );

      expect(find.text('Login failed'), findsOneWidget);

      expect(find.text('Invalid credentials.'), findsOneWidget);

      await tester.tap(find.text('Try again'));

      await tester.pump();

      expect(retryCalled, isTrue);
    });
  });

  group('AppEmptyStateWidget', () {
    testWidgets('shows empty state title and message', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AppEmptyStateWidget(
            title: 'No appointments',
            message: 'You do not have appointments yet.',
            scrollable: false,
          ),
        ),
      );

      expect(find.text('No appointments'), findsOneWidget);

      expect(find.text('You do not have appointments yet.'), findsOneWidget);

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('empty state action invokes callback', (tester) async {
      var actionCalled = false;

      await tester.pumpWidget(
        wrap(
          AppEmptyStateWidget(
            title: 'No results',
            message: 'No data found.',
            actionLabel: 'Refresh',
            onAction: () {
              actionCalled = true;
            },
            scrollable: false,
          ),
        ),
      );

      await tester.tap(find.text('Refresh'));

      await tester.pump();

      expect(actionCalled, isTrue);
    });

    testWidgets('inline empty state displays message', (tester) async {
      await tester.pumpWidget(
        wrap(const AppInlineEmptyState(message: 'No reviews found.')),
      );

      expect(find.text('No reviews found.'), findsOneWidget);
    });
  });
}
