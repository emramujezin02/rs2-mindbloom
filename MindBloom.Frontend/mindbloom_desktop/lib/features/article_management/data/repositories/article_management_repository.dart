import 'package:mindbloom_desktop/features/article_management/data/models/article_from_request.dart';

import '../models/article_management_model.dart';
import '../models/article_paged_response.dart';
import '../services/article_management_api_service.dart';

class ArticleManagementRepository {
  final ArticleManagementApiService apiService;

  ArticleManagementRepository({required this.apiService});

  Future<ArticlePagedResponse> getArticles({
    required int pageNumber,
    required int pageSize,
    String? search,
    bool? isPublished,
  }) {
    return apiService.getArticles(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
      isPublished: isPublished,
    );
  }

  Future<ArticleManagementModel> getArticle(int articleId) {
    return apiService.getArticle(articleId);
  }

  Future<ArticleManagementModel> createArticle(ArticleFormRequest request) {
    return apiService.createArticle(request);
  }

  Future<ArticleManagementModel> updateArticle(
    int articleId,
    ArticleFormRequest request,
  ) {
    return apiService.updateArticle(articleId, request);
  }

  Future<ArticleManagementModel> updatePublication({
    required int articleId,
    required bool isPublished,
  }) {
    return apiService.updatePublication(
      articleId: articleId,
      isPublished: isPublished,
    );
  }

  Future<void> deleteArticle(int articleId) {
    return apiService.deleteArticle(articleId);
  }
}
