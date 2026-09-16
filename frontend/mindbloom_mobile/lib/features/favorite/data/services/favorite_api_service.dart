import '../../../../core/network/api_client.dart';
import '../../../../core/models/paged_response.dart';
import '../models/add_favorite_request.dart';
import '../models/favorite_model.dart';

class FavoriteApiService {
  final ApiClient apiClient;

  FavoriteApiService({required this.apiClient});

  Future<PagedResponse<FavoriteModel>> getMyFavorites({
    required int pageNumber,
    required int pageSize,
    int? therapistId,
  }) async {
    final query = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
      if (therapistId != null) 'therapistId': therapistId.toString(),
    };

    final response = await apiClient.get(
      Uri(path: '/Favorites/mine', queryParameters: query).toString(),
    );

    return PagedResponse.fromJson(
      response as Map<String, dynamic>,
      FavoriteModel.fromJson,
    );
  }

  Future<void> addFavorite(int therapistId) async {
    final request = AddFavoriteRequest(therapistId: therapistId);

    await apiClient.post('/Favorites', body: request.toJson());
  }

  Future<void> removeFavorite(int therapistId) async {
    await apiClient.delete('/Favorites/$therapistId');
  }
}
