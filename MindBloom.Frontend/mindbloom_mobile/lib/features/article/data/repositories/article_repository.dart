import '../models/article_model.dart';
import '../services/article_api_service.dart';

class ArticleRepository {
  final ArticleApiService apiService;

  ArticleRepository({required this.apiService});

  Future<List<ArticleModel>> getArticles() {
    return apiService.getArticles();
  }
}
