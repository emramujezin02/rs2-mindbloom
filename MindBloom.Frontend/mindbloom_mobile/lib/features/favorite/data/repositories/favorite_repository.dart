import '../models/favorite_model.dart';
import '../services/favorite_api_service.dart';

class FavoriteRepository {
  final FavoriteApiService apiService;

  FavoriteRepository({required this.apiService});

  Future<List<FavoriteModel>> getMyFavorites() {
    return apiService.getMyFavorites();
  }

  Future<void> addFavorite(int therapistId) {
    return apiService.addFavorite(therapistId);
  }

  Future<void> removeFavorite(int therapistId) {
    return apiService.removeFavorite(therapistId);
  }
}
