import '../models/article_category_model.dart';
import '../models/article_model.dart';
import '../models/article_paged_response.dart';
import '../services/article_api_service.dart';

class ArticleRepository {
  final ArticleApiService apiService;

  ArticleRepository({required this.apiService});

  Future<ArticlePagedResponse> getArticles({
    required int pageNumber,
    required int pageSize,
    String? search,
    int? articleCategoryId,
  }) {
    return apiService.getArticles(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
      articleCategoryId: articleCategoryId,
    );
  }

  Future<ArticleModel> getArticle(int articleId) {
    return apiService.getArticle(articleId);
  }

  Future<List<ArticleCategoryModel>> getCategories() {
    return apiService.getCategories();
  }
}
