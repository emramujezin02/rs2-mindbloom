import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';
import 'package:mindbloom_mobile/features/article/data/repositories/article_repository.dart';
import 'package:mindbloom_mobile/features/article/data/services/article_api_service.dart';
import 'package:mindbloom_mobile/features/article/presentation/viewmodels/article_viewmodel.dart';
import 'package:mindbloom_mobile/features/article/presentation/widgets/article_pagination.dart';
import 'package:mindbloom_mobile/features/article/presentation/pages/article_list_page.dart';
import 'package:mindbloom_mobile/features/article/presentation/pages/article_details_page.dart';

Map<String, dynamic> article(
  int id, {
  int? category = 7,
  bool published = true,
}) => {
  'id': id,
  'title': 'Article $id',
  'content': 'Body $id',
  'isPublished': published,
  'articleCategoryId': category,
  'articleCategoryName': 'Education',
  'publishedAtUtc': '2026-10-30T12:00:00Z',
};
Map<String, dynamic> page(
  int number, {
  int pages = 3,
  List<Map<String, dynamic>>? items,
}) => {
  'items': items ?? [article(number * 10)],
  'pageNumber': number,
  'pageSize': 10,
  'totalPages': pages,
  'totalCount': pages * 10,
};

class Api extends ApiClient {
  final requests = <Uri>[];
  Future<dynamic> Function(Uri)? handler;
  Api() : super(sessionStorage: SessionStorageService());
  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    expect(requiresAuth, false);
    final uri = Uri.parse(endpoint);
    requests.add(uri);
    if (handler != null) return handler!(uri);
    if (uri.path.endsWith('categories')) {
      return [
        {'id': 7, 'name': 'Education'},
      ];
    }
    if (uri.path.startsWith('/Articles/')) {
      return article(int.parse(uri.path.split('/').last));
    }
    if (uri.queryParameters['pageSize'] == '4') {
      return page(1, items: [article(1), article(2), article(3), article(4)]);
    }
    return page(int.parse(uri.queryParameters['pageNumber']!));
  }
}

ArticleViewModel model(Api api) => ArticleViewModel(
  repository: ArticleRepository(apiService: ArticleApiService(apiClient: api)),
);

Future<void> reveal(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 40 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  testWidgets('zero results hide pagination; one page disables both arrows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArticlePagination(
            currentPage: 1,
            totalPages: 0,
            onPageChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(TextButton), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArticlePagination(
            currentPage: 1,
            totalPages: 1,
            onPageChanged: (_) {},
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
    expect(find.byKey(const ValueKey('article-page-1')), findsOneWidget);
  });
  testWidgets(
    'loading pagination disables requests and exposes selected page',
    (tester) async {
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArticlePagination(
              currentPage: 2,
              totalPages: 3,
              isLoading: true,
              onPageChanged: (_) => requests++,
            ),
          ),
        ),
      );
      for (final button in tester.widgetList<TextButton>(
        find.byType(TextButton),
      )) {
        expect(button.onPressed, isNull);
      }
      final selected = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('article-page-2')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(selected.properties.selected, true);
      expect(requests, 0);
    },
  );
  testWidgets(
    'article list shows error then retries without user filter loss',
    (tester) async {
      final api = Api();
      api.handler = (uri) async {
        if (uri.path.endsWith('categories')) return [];
        throw StateError('Offline');
      };
      final vm = model(api);
      await tester.pumpWidget(
        MaterialApp(home: ArticleListPage(viewModel: vm)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Articles could not be loaded'), findsOneWidget);
      api.handler = (uri) async => page(1);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Article 10'), findsOneWidget);
      expect(vm.error, isNull);
    },
  );
  testWidgets('search and category controls reset real list to page one', (
    tester,
  ) async {
    final api = Api();
    final vm = model(api);
    await tester.pumpWidget(MaterialApp(home: ArticleListPage(viewModel: vm)));
    await tester.pumpAndSettle();
    await vm.goToPage(3);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'care');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(vm.pageNumber, 1);
    expect(vm.currentSearch, 'care');
    await vm.goToPage(2);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Education').last);
    await tester.pumpAndSettle();
    expect(vm.pageNumber, 1);
    expect(vm.selectedArticleCategoryId, 7);
    expect(api.requests.last.queryParameters['search'], 'care');
  });
  testWidgets(
    'related loading then error leaves readable detail and supports retry',
    (tester) async {
      final api = Api();
      final related = Completer<dynamic>();
      api.handler = (uri) async =>
          uri.path == '/Articles/1' ? article(1) : await related.future;
      final vm = model(api);
      await tester.pumpWidget(
        MaterialApp(home: ArticleDetailsPage(articleId: 1, viewModel: vm)),
      );
      await tester.pump();
      await tester.pump();
      expect(vm.isLoadingRelated, true);
      expect(vm.selectedArticle!.id, 1);
      related.completeError(StateError('Offline'));
      await tester.pumpAndSettle();
      expect(vm.relatedError, isNotNull);
      expect(vm.selectedArticle!.id, 1);
      api.handler = (_) async => page(1, items: [article(2)]);
      await vm.loadRelatedArticles();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Article 2'));
      expect(vm.relatedError, isNull);
    },
  );

  test(
    'server page replaces results; filters reset and are preserved on page changes',
    () async {
      final api = Api();
      final vm = model(api);
      addTearDown(vm.dispose);
      await vm.loadArticles();
      expect(vm.articles.single.id, 10);
      await vm.goToPage(3);
      expect(vm.articles.single.id, 30);
      await vm.searchArticles('  care  ');
      expect(vm.pageNumber, 1);
      await vm.filterByCategory(7);
      await vm.goToPage(2);
      expect(api.requests.last.queryParameters, {
        'pageNumber': '2',
        'pageSize': '10',
        'search': 'care',
        'articleCategoryId': '7',
      });
      expect(vm.articles.single.id, 20);
      final count = api.requests.length;
      await vm.goToPage(0);
      await vm.goToPage(4);
      await vm.goToPage(2);
      expect(api.requests.length, count);
      await vm.clearSearch();
      expect(vm.currentSearch, '');
      expect(vm.pageNumber, 1);
    },
  );
  test(
    'late page and filter responses cannot overwrite newest results',
    () async {
      final api = Api();
      final vm = model(api);
      addTearDown(vm.dispose);
      await vm.loadArticles();
      final old = Completer<dynamic>();
      api.handler = (uri) async => uri.queryParameters['pageNumber'] == '2'
          ? await old.future
          : page(1, items: [article(99)]);
      final pending = vm.goToPage(2);
      await vm.filterByCategory(8);
      old.complete(page(2));
      await pending;
      expect(vm.pageNumber, 1);
      expect(vm.articles.single.id, 99);
      expect(vm.isLoading, false);
    },
  );
  test('rapid numbered clicks keep the last requested page', () async {
    final api = Api();
    final vm = model(api);
    addTearDown(vm.dispose);
    await vm.loadArticles();
    final old = Completer<dynamic>();
    api.handler = (uri) async =>
        uri.queryParameters['pageNumber'] == '2' ? await old.future : page(3);
    final pending = vm.goToPage(2);
    await vm.goToPage(3);
    old.complete(page(2));
    await pending;
    expect(vm.pageNumber, 3);
    expect(vm.articles.single.id, 30);
  });
  test('page error retries same page and keeps filters', () async {
    final api = Api();
    final vm = model(api);
    addTearDown(vm.dispose);
    await vm.filterByCategory(7);
    api.handler = (_) async => throw StateError('Offline');
    await vm.goToPage(2);
    expect(vm.error, isNotNull);
    expect(vm.articles, isEmpty);
    expect(vm.isLoading, false);
    api.handler = (uri) async =>
        page(int.parse(uri.queryParameters['pageNumber']!));
    await vm.refreshArticles();
    expect(vm.pageNumber, 2);
    expect(vm.error, isNull);
  });
  test(
    'removed final page loads new final page; empty results have no pages',
    () async {
      final api = Api();
      final vm = model(api);
      addTearDown(vm.dispose);
      await vm.loadArticles();
      api.handler = (uri) async =>
          page(int.parse(uri.queryParameters['pageNumber']!), pages: 2);
      await vm.goToPage(3);
      expect(vm.pageNumber, 2);
      expect(vm.articles.single.id, 20);
      api.handler = (_) async => page(1, pages: 0, items: []);
      await vm.loadArticles();
      expect(vm.totalPages, 0);
      expect(vm.articles, isEmpty);
    },
  );
  test('disposing during a request prevents notifications', () async {
    final api = Api();
    final vm = model(api);
    final response = Completer<dynamic>();
    api.handler = (_) => response.future;
    final pending = vm.loadArticles();
    vm.dispose();
    response.complete(page(1));
    await pending;
    expect(vm.articles, isEmpty);
  });
  for (final count in [0, 1, 2, 3]) {
    test(
      'related response with $count candidates excludes self and uses bounded server category query',
      () async {
        final api = Api();
        final vm = model(api);
        addTearDown(vm.dispose);
        api.handler = (uri) async => uri.path == '/Articles/1'
            ? article(1)
            : page(
                1,
                items: [
                  article(1),
                  for (var i = 0; i < count; i++) article(i + 2),
                ],
              );
        await vm.loadArticleDetails(1);
        expect(vm.relatedArticles.map((a) => a.id), [
          for (var i = 0; i < count; i++) i + 2,
        ]);
        expect(api.requests.last.queryParameters, {
          'pageNumber': '1',
          'pageSize': '4',
          'articleCategoryId': '7',
        });
      },
    );
  }
  test(
    'related ignores duplicate, other category and unpublished records defensively',
    () async {
      final api = Api();
      final vm = model(api);
      addTearDown(vm.dispose);
      api.handler = (uri) async => uri.path == '/Articles/1'
          ? article(1)
          : page(
              1,
              items: [
                article(2),
                article(2),
                article(3, category: 8),
                article(4, published: false),
              ],
            );
      await vm.loadArticleDetails(1);
      expect(vm.relatedArticles.map((a) => a.id), [2]);
    },
  );
  test('uncategorized detail does not request unrelated content', () async {
    final api = Api();
    final vm = model(api);
    addTearDown(vm.dispose);
    api.handler = (_) async => article(1, category: null);
    await vm.loadArticleDetails(1);
    expect(api.requests.length, 1);
    expect(vm.relatedArticles, isEmpty);
  });
  test('related failure preserves detail and can retry', () async {
    final api = Api();
    final vm = model(api);
    addTearDown(vm.dispose);
    api.handler = (uri) async =>
        uri.path == '/Articles/1' ? article(1) : throw StateError('Offline');
    await vm.loadArticleDetails(1);
    expect(vm.selectedArticle!.id, 1);
    expect(vm.relatedError, isNotNull);
    api.handler = (_) async => page(1, items: [article(2)]);
    await vm.loadRelatedArticles();
    expect(vm.relatedError, isNull);
    expect(vm.relatedArticles.single.id, 2);
  });
  test('changing detail discards previous related request', () async {
    final api = Api();
    final vm = model(api);
    addTearDown(vm.dispose);
    final old = Completer<dynamic>();
    api.handler = (uri) async {
      if (uri.path == '/Articles/1') return article(1);
      if (uri.path == '/Articles/2') return article(2, category: null);
      return old.future;
    };
    final pending = vm.loadArticleDetails(1);
    await Future<void>.delayed(Duration.zero);
    await vm.loadArticleDetails(2);
    old.complete(page(1));
    await pending;
    expect(vm.selectedArticle!.id, 2);
    expect(vm.relatedArticles, isEmpty);
    expect(vm.isLoadingRelated, false);
  });
  for (final total in [0, 1, 3, 7, 25, 1000]) {
    test(
      'pagination labels for $total pages have no duplicates or invalid pages',
      () {
        for (final compact in [false, true]) {
          final current = total == 0 ? 1 : (total / 2).ceil();
          final labels = articlePageLabels(current, total, compact: compact);
          final numbers = labels.whereType<int>().toList();
          expect(numbers.toSet().length, numbers.length);
          expect(numbers.every((p) => p >= 1 && p <= total), true);
          if (total > 0) {
            expect(numbers, contains(current));
            expect(numbers.first, 1);
            expect(numbers.last, total);
          }
          if (total > 7) expect(labels, contains(null));
        }
      },
    );
  }
  testWidgets(
    'pagination arrows and numbers request pages; boundary arrows disabled',
    (tester) async {
      var current = 1;
      Future<void> show(int selected) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArticlePagination(
              currentPage: selected,
              totalPages: 3,
              onPageChanged: (p) => current = p,
            ),
          ),
        ),
      );
      await show(1);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('article-page-2')));
      expect(current, 2);
      await show(2);
      await tester.tap(find.byTooltip('Next page'));
      expect(current, 3);
      await show(3);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Previous page'));
      expect(current, 2);
    },
  );
  for (final width in [320.0, 390.0, 600.0, 1024.0]) {
    testWidgets(
      'pagination and related content fit width $width with enlarged text',
      (tester) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: ArticlePagination(
                currentPage: 500,
                totalPages: 1000,
                onPageChanged: (_) {},
              ),
            ),
          ),
        );
        expect(find.byKey(const ValueKey('article-page-500')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: ArticleDetailsPage(articleId: 1, viewModel: model(Api())),
          ),
        );
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const ValueKey('related-article-2')));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('related card navigates to correct real detail and back', (
    tester,
  ) async {
    final api = Api();
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleDetailsPage(articleId: 1, viewModel: model(api)),
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => ArticleDetailsPage(
            articleId: settings.arguments! as int,
            viewModel: model(api),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('related-article-2')));
    await reveal(tester, find.text('Article 2'));
    await tester.tap(find.text('Article 2'));
    await tester.pumpAndSettle();
    expect(find.text('Article 2'), findsOneWidget);
    await reveal(tester, find.text('Body 2'));
    expect(find.text('Body 2'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('related-article-2')), findsOneWidget);
  });
  testWidgets('same details widget reloads when article ID changes', (
    tester,
  ) async {
    final vm = model(Api());
    await tester.pumpWidget(
      MaterialApp(home: ArticleDetailsPage(articleId: 1, viewModel: vm)),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(home: ArticleDetailsPage(articleId: 2, viewModel: vm)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Article 2'), findsOneWidget);
    expect(vm.selectedArticle!.id, 2);
  });
  testWidgets(
    'real article list changes server page and restores state after detail',
    (tester) async {
      final api = Api();
      final vm = model(api);
      await tester.pumpWidget(
        MaterialApp(
          home: ArticleListPage(viewModel: vm),
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (_) => ArticleDetailsPage(
              articleId: settings.arguments! as int,
              viewModel: model(api),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('article-page-2')));
      await tester.tap(find.byKey(const ValueKey('article-page-2')));
      await tester.pumpAndSettle();
      expect(find.text('Article 20'), findsOneWidget);
      expect(find.text('Article 10'), findsNothing);
      expect(find.text('Load more'), findsNothing);
      await reveal(tester, find.text('Article 20'));
      await tester.tap(find.text('Article 20'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(vm.pageNumber, 2);
      expect(find.text('Article 20'), findsOneWidget);
    },
  );
}
