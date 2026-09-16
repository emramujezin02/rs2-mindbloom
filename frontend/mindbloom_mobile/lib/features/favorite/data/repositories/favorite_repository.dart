import '../models/favorite_model.dart';
import '../services/favorite_api_service.dart';
import '../../../../core/models/paged_response.dart';

class FavoriteRepository {
  final FavoriteApiService apiService;

  FavoriteRepository({required this.apiService});

  Future<PagedResponse<FavoriteModel>> getMyFavorites({
    required int pageNumber,
    required int pageSize,
    int? therapistId,
  }) {
    return apiService.getMyFavorites(
      pageNumber: pageNumber,
      pageSize: pageSize,
      therapistId: therapistId,
    );
  }

  Future<bool> isFavorite(int therapistId) async {
    final result = await getMyFavorites(
      pageNumber: 1,
      pageSize: 1,
      therapistId: therapistId,
    );

    return result.items.any(
      (favorite) => favorite.therapistId == therapistId,
    );
  }

  Future<void> addFavorite(int therapistId) {
    return apiService.addFavorite(therapistId);
  }

  Future<void> removeFavorite(int therapistId) {
    return apiService.removeFavorite(therapistId);
  }
}
