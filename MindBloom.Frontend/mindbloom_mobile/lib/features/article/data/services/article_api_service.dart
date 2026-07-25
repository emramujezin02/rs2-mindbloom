import '../../../../core/network/api_client.dart';
import '../models/article_category_model.dart';
import '../models/article_model.dart';
import '../models/article_paged_response.dart';

class ArticleApiService {
  final ApiClient apiClient;

  ArticleApiService({
    required this.apiClient,
  });

  Future<ArticlePagedResponse> getArticles({
    required int pageNumber,
    required int pageSize,
    String? search,
    int? articleCategoryId,
  }) async {
    final queryParameters =
        <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
    };

    final normalizedSearch =
        search?.trim() ?? '';

    if (normalizedSearch.isNotEmpty) {
      queryParameters['search'] =
          normalizedSearch;
    }

    if (articleCategoryId != null) {
      queryParameters['articleCategoryId'] =
          articleCategoryId.toString();
    }

    final uri = Uri(
      path: '/Articles',
      queryParameters: queryParameters,
    );

    final response =
        await apiClient.get(
      uri.toString(),
    );

    if (response is! Map) {
      throw const FormatException(
        'Invalid article list response.',
      );
    }

    return ArticlePagedResponse.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<ArticleModel> getArticle(
    int articleId,
  ) async {
    final response =
        await apiClient.get(
      '/Articles/$articleId',
    );

    if (response is! Map) {
      throw const FormatException(
        'Invalid article response.',
      );
    }

    return ArticleModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<List<ArticleCategoryModel>>
      getCategories() async {
    final response =
        await apiClient.get(
      '/Articles/categories',
    );

    if (response is! List) {
      throw const FormatException(
        'Invalid article category response.',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (item) =>
              ArticleCategoryModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}