import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_desktop/core/widgets/app_table_pagination.dart';

void main() {
  Widget wrap(Widget child, {double width = 1200}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  group('AdminTablePagination', () {
    testWidgets('shows current result range and page', (tester) async {
      await tester.pumpWidget(
        wrap(
          AdminTablePagination(
            pageNumber: 2,
            pageSize: 10,
            totalCount: 35,
            totalPages: 4,
            isLoading: false,
            onPreviousPage: () {},
            onNextPage: () {},
            onPageSizeChanged: (_) {},
          ),
        ),
      );

      expect(find.text('11–20 od 35'), findsOneWidget);

      expect(find.text('Stranica 2 od 4'), findsOneWidget);

      expect(find.text('Redova po stranici:'), findsOneWidget);
    });

    testWidgets('previous page callback is executed', (tester) async {
      var previousCalled = false;

      await tester.pumpWidget(
        wrap(
          AdminTablePagination(
            pageNumber: 2,
            pageSize: 10,
            totalCount: 30,
            totalPages: 3,
            isLoading: false,
            onPreviousPage: () {
              previousCalled = true;
            },
            onNextPage: () {},
            onPageSizeChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_left));

      await tester.pump();

      expect(previousCalled, isTrue);
    });

    testWidgets('next page callback is executed', (tester) async {
      var nextCalled = false;

      await tester.pumpWidget(
        wrap(
          AdminTablePagination(
            pageNumber: 1,
            pageSize: 10,
            totalCount: 30,
            totalPages: 3,
            isLoading: false,
            onPreviousPage: () {},
            onNextPage: () {
              nextCalled = true;
            },
            onPageSizeChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_right));

      await tester.pump();

      expect(nextCalled, isTrue);
    });

    testWidgets('previous page is disabled on first page', (tester) async {
      await tester.pumpWidget(
        wrap(
          AdminTablePagination(
            pageNumber: 1,
            pageSize: 10,
            totalCount: 30,
            totalPages: 3,
            isLoading: false,
            onPreviousPage: () {},
            onNextPage: () {},
            onPageSizeChanged: (_) {},
          ),
        ),
      );

      final previousButton = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.chevron_left),
              matching: find.byType(IconButton),
            )
            .first,
      );

      expect(previousButton.onPressed, isNull);
    });

    testWidgets('next page is disabled on final page', (tester) async {
      await tester.pumpWidget(
        wrap(
          AdminTablePagination(
            pageNumber: 3,
            pageSize: 10,
            totalCount: 30,
            totalPages: 3,
            isLoading: false,
            onPreviousPage: () {},
            onNextPage: () {},
            onPageSizeChanged: (_) {},
          ),
        ),
      );

      final nextButton = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.chevron_right),
              matching: find.byType(IconButton),
            )
            .first,
      );

      expect(nextButton.onPressed, isNull);
    });

    testWidgets('navigation is disabled while loading', (tester) async {
      await tester.pumpWidget(
        wrap(
          AdminTablePagination(
            pageNumber: 2,
            pageSize: 10,
            totalCount: 30,
            totalPages: 3,
            isLoading: true,
            onPreviousPage: () {},
            onNextPage: () {},
            onPageSizeChanged: (_) {},
          ),
        ),
      );

      final previousButton = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.chevron_left),
              matching: find.byType(IconButton),
            )
            .first,
      );

      final nextButton = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.chevron_right),
              matching: find.byType(IconButton),
            )
            .first,
      );

      expect(previousButton.onPressed, isNull);

      expect(nextButton.onPressed, isNull);
    });

    testWidgets('shows empty pagination state', (tester) async {
      await tester.pumpWidget(
        wrap(
          AdminTablePagination(
            pageNumber: 1,
            pageSize: 10,
            totalCount: 0,
            totalPages: 0,
            isLoading: false,
            onPreviousPage: () {},
            onNextPage: () {},
            onPageSizeChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Ukupno: 0'), findsOneWidget);

      expect(find.text('Stranica 0 od 0'), findsOneWidget);
    });

    testWidgets('page size change invokes callback', (tester) async {
      int? selectedPageSize;

      await tester.pumpWidget(
        wrap(
          AdminTablePagination(
            pageNumber: 1,
            pageSize: 10,
            totalCount: 30,
            totalPages: 3,
            isLoading: false,
            onPreviousPage: () {},
            onNextPage: () {},
            onPageSizeChanged: (value) {
              selectedPageSize = value;
            },
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButton<int>));

      await tester.pumpAndSettle();

      await tester.tap(find.text('20').last);

      await tester.pumpAndSettle();

      expect(selectedPageSize, 20);
    });

    testWidgets('renders correctly in compact layout', (tester) async {
      await tester.pumpWidget(
        wrap(
          AdminTablePagination(
            pageNumber: 1,
            pageSize: 10,
            totalCount: 15,
            totalPages: 2,
            isLoading: false,
            onPreviousPage: () {},
            onNextPage: () {},
            onPageSizeChanged: (_) {},
          ),
          width: 600,
        ),
      );

      expect(find.text('1–10 od 15'), findsOneWidget);

      expect(find.text('Stranica 1 od 2'), findsOneWidget);
    });
  });
}
