import 'package:mindbloom_desktop/features/article_management/data/models/article_from_request.dart';

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

    final queryString = Uri(queryParameters: query).query;

    final response = await apiClient.get('/Articles/management?$queryString');

    return ArticlePagedResponse.fromJson(Map<String, dynamic>.from(response));
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
}
