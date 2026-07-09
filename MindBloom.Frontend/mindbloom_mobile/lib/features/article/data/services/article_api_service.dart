import '../../../../core/network/api_client.dart';
import '../models/article_model.dart';

class ArticleApiService {
  final ApiClient apiClient;

  ArticleApiService({required this.apiClient});

  Future<List<ArticleModel>> getArticles() async {
    final response = await apiClient.get('/Articles');

    return (response as List).map((e) => ArticleModel.fromJson(e)).toList();
  }
}
