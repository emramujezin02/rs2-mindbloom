import 'package:flutter/foundation.dart';
import '../../../favorite/data/models/favorite_model.dart';
import '../../../favorite/data/repositories/favorite_repository.dart';
import '../../data/models/therapist_filter_request.dart';
import '../../data/models/therapist_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistListViewModel extends ChangeNotifier {
  final TherapistRepository therapistRepository;

  final FavoriteRepository favoriteRepository;

  bool isLoading = false;
  String? errorMessage;

  List<TherapistModel> therapists = [];

  final Set<int> favoriteTherapistIds = <int>{};

  TherapistListViewModel({
    required this.therapistRepository,
    required this.favoriteRepository,
  });

  Future<void> loadTherapists() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        therapistRepository.getTherapists(),
        favoriteRepository.getMyFavorites(),
      ]);

      therapists = results[0] as List<TherapistModel>;

      final favorites = results[1] as List<FavoriteModel>;

      favoriteTherapistIds
        ..clear()
        ..addAll(favorites.map((favorite) => favorite.therapistId));
    } catch (error) {
      errorMessage = error.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> searchTherapists({
    String? name,
    String? specialization,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      therapists = await therapistRepository.searchTherapists(
        TherapistFilterRequest(
          name: name,
          specialization: specialization,
          minPrice: minPrice,
          maxPrice: maxPrice,
          sortBy: sortBy,
        ),
      );

      await loadFavoriteIds();
    } catch (error) {
      errorMessage = error.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadFavoriteIds() async {
    final favorites = await favoriteRepository.getMyFavorites();

    favoriteTherapistIds
      ..clear()
      ..addAll(favorites.map((favorite) => favorite.therapistId));

    notifyListeners();
  }

  bool isFavorite(int therapistId) {
    return favoriteTherapistIds.contains(therapistId);
  }

  Future<bool> toggleFavorite(int therapistId) async {
    errorMessage = null;

    try {
      if (isFavorite(therapistId)) {
        await favoriteRepository.removeFavorite(therapistId);

        favoriteTherapistIds.remove(therapistId);
      } else {
        await favoriteRepository.addFavorite(therapistId);

        favoriteTherapistIds.add(therapistId);
      }

      notifyListeners();

      return true;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();

      return false;
    }
  }
}
