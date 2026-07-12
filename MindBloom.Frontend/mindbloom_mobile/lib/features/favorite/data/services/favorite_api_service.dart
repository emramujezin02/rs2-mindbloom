import '../../../../core/network/api_client.dart';
import '../models/add_favorite_request.dart';
import '../models/favorite_model.dart';

class FavoriteApiService {
  final ApiClient apiClient;

  FavoriteApiService({required this.apiClient});

  Future<List<FavoriteModel>> getMyFavorites() async {
    final response = await apiClient.get('/Favorites/mine');

    return (response as List)
        .map((item) => FavoriteModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> addFavorite(int therapistId) async {
    final request = AddFavoriteRequest(therapistId: therapistId);

    await apiClient.post('/Favorites', body: request.toJson());
  }

  Future<void> removeFavorite(int therapistId) async {
    await apiClient.delete('/Favorites/$therapistId');
  }
}
