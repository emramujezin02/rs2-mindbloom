import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_desktop/core/network/api_client.dart';
import 'package:mindbloom_desktop/services/session_storage_service.dart';
import 'package:mindbloom_desktop/features/article_management/data/repositories/article_management_repository.dart';
import 'package:mindbloom_desktop/features/article_management/data/services/article_management_api_service.dart';
import 'package:mindbloom_desktop/features/reference_data/data/services/reference_data_api_service.dart';
import 'package:mindbloom_desktop/features/reference_data/presentation/widgets/featured_article_picker.dart';

void main() {
  testWidgets(
    'published picker loads all pages and supports explicit selection and removal',
    (tester) async {
      final api = _Api();
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => FeaturedArticlePicker(
                repository: ArticleManagementRepository(
                  apiService: ArticleManagementApiService(apiClient: api),
                ),
                selectedId: selected,
                onChanged: (id) => setState(() => selected = id),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.pages, [1, 2]);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Article 2').last);
      await tester.pumpAndSettle();
      expect(selected, 2);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bez članka').last);
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unavailable current article is retained and loading failure offers retry',
    (tester) async {
      final api = _Api()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeaturedArticlePicker(
              repository: ArticleManagementRepository(
                apiService: ArticleManagementApiService(apiClient: api),
              ),
              selectedId: 99,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Pokušaj ponovo'), findsOneWidget);
      api.fail = false;
      await tester.tap(find.textContaining('Pokušaj ponovo'));
      await tester.pumpAndSettle();
      expect(find.text('Trenutni članak nije javno dostupan'), findsOneWidget);
    },
  );

  test(
    'admin API explicitly assigns and clears while legacy updates preserve link',
    () async {
      final api = _Api();
      final service = ReferenceDataApiService(apiClient: api);
      await service.updateTherapyApproach(
        id: 1,
        name: 'CBT',
        featuredArticleId: 2,
        updateFeaturedArticle: true,
      );
      expect(api.body?['featuredArticleId'], 2);
      await service.updateTherapyApproach(
        id: 1,
        name: 'CBT',
        updateFeaturedArticle: true,
      );
      expect(api.body?['featuredArticleId'], isNull);
      expect(api.body?['updateFeaturedArticle'], true);
      await service.updateTherapyApproach(id: 1, name: 'CBT');
      expect(api.body?['updateFeaturedArticle'], false);
    },
  );
}

class _Api extends ApiClient {
  bool fail = false;
  final pages = <int>[];
  Map<String, dynamic>? body;
  _Api() : super(sessionStorage: SessionStorageService());
  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    if (fail) throw StateError('Unavailable');
    final uri = Uri.parse(endpoint);
    expect(uri.queryParameters['IsPublished'], 'true');
    final page = int.parse(uri.queryParameters['PageNumber']!);
    pages.add(page);
    return {
      'items': [
        {'id': page, 'title': 'Article $page', 'isPublished': true},
      ],
      'pageNumber': page,
      'pageSize': 100,
      'totalPages': 2,
      'totalCount': 2,
    };
  }

  @override
  Future<dynamic> put(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
    String? idempotencyKey,
  }) async {
    this.body = body as Map<String, dynamic>?;
    return {'id': 1, 'name': 'CBT', 'createdAtUtc': '2026-10-30T00:00:00Z'};
  }
}
