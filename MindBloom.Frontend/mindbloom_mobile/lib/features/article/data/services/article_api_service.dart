import '../../../../core/network/api_client.dart';
import '../models/article_model.dart';
import '../models/article_paged_response.dart';

class ArticleApiService {
  final ApiClient apiClient;

  ArticleApiService({required this.apiClient});

  Future<ArticlePagedResponse> getArticles({
    required int pageNumber,
    required int pageSize,
    String? search,
  }) async {
    final queryParameters = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
    };

    final normalizedSearch = search?.trim() ?? '';

    if (normalizedSearch.isNotEmpty) {
      queryParameters['search'] = normalizedSearch;
    }

    final uri = Uri(path: '/Articles', queryParameters: queryParameters);

    final response = await apiClient.get(uri.toString());

    return ArticlePagedResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<ArticleModel> getArticle(int articleId) async {
    final response = await apiClient.get('/Articles/$articleId');

    return ArticleModel.fromJson(response as Map<String, dynamic>);
  }
}
