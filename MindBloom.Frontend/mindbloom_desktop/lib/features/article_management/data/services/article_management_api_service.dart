import 'package:mindbloom_desktop/features/article_management/data/models/article_form_request.dart';
import '../models/article_category_model.dart';
import '../../../../core/network/api_client.dart';
import '../models/article_management_model.dart';
import '../models/article_paged_response.dart';

class ArticleManagementApiService {
  final ApiClient apiClient;

  ArticleManagementApiService({required this.apiClient});

  Future<ArticlePagedResponse> getArticles({
    required int pageNumber,
    required int pageSize,
    String? search,
    bool? isPublished,
    int? articleCategoryId,
  }) async {
    final query = <String, String>{
      'PageNumber': pageNumber.toString(),
      'PageSize': pageSize.toString(),
    };

    final normalizedSearch = search?.trim() ?? '';

    if (normalizedSearch.isNotEmpty) {
      query['Search'] = normalizedSearch;
    }

    if (isPublished != null) {
      query['IsPublished'] = isPublished.toString();
    }

    if (articleCategoryId != null) {
      query['ArticleCategoryId'] = articleCategoryId.toString();
    }

    final queryString = Uri(queryParameters: query).query;

    final response = await apiClient.get('/Articles/management?$queryString');

    return ArticlePagedResponse.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<ArticleCategoryModel>> getCategories() async {
    final response = await apiClient.get('/Articles/categories');

    if (response is! List) {
      throw Exception('The server returned invalid article categories.');
    }

    return response
        .whereType<Map>()
        .map(
          (item) =>
              ArticleCategoryModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<ArticleManagementModel> getArticle(int articleId) async {
    final response = await apiClient.get('/Articles/management/$articleId');

    return ArticleManagementModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ArticleManagementModel> createArticle(
    ArticleFormRequest request,
  ) async {
    final response = await apiClient.post('/Articles', body: request.toJson());

    return ArticleManagementModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ArticleManagementModel> updateArticle(
    int articleId,
    ArticleFormRequest request,
  ) async {
    final response = await apiClient.put(
      '/Articles/$articleId',
      body: request.toJson(),
    );

    return ArticleManagementModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<ArticleManagementModel> updatePublication({
    required int articleId,
    required bool isPublished,
  }) async {
    final response = await apiClient.put(
      '/Articles/$articleId/publication',
      body: {'isPublished': isPublished},
    );

    return ArticleManagementModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> deleteArticle(int articleId) async {
    await apiClient.delete('/Articles/$articleId');
  }

  Future<String> uploadArticleImage(String filePath) async {
    final response = await apiClient.postMultipartFile(
      '/Articles/image',
      filePath: filePath,
      fieldName: 'file',
    );

    if (response is! Map) {
      throw Exception('The server returned invalid image upload data.');
    }

    final data = Map<String, dynamic>.from(response);

    final imageUrl = data['imageUrl']?.toString().trim();

    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('The server did not return an image URL.');
    }

    return imageUrl;
  }
}
