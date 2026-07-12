import 'package:flutter/foundation.dart';
import '../../../favorite/data/models/favorite_model.dart';
import '../../../favorite/data/repositories/favorite_repository.dart';
import '../../data/models/therapist_details_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistDetailsViewModel extends ChangeNotifier {
  final TherapistRepository repository;

  final FavoriteRepository favoriteRepository;

  TherapistDetailsViewModel({
    required this.repository,
    required this.favoriteRepository,
  });

  bool isLoading = false;
  bool isChangingFavorite = false;

  String? errorMessage;

  TherapistDetailsModel? therapist;

  bool isFavorite = false;

  Future<void> loadTherapist(int therapistId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        repository.getTherapistById(therapistId),
        favoriteRepository.getMyFavorites(),
      ]);

      therapist = results[0] as TherapistDetailsModel;

      final favorites = results[1] as List<FavoriteModel>;

      isFavorite = favorites.any(
        (favorite) => favorite.therapistId == therapistId,
      );
    } catch (error) {
      errorMessage = error.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> toggleFavorite() async {
    final currentTherapist = therapist;

    if (currentTherapist == null) {
      return false;
    }

    isChangingFavorite = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (isFavorite) {
        await favoriteRepository.removeFavorite(currentTherapist.id);
      } else {
        await favoriteRepository.addFavorite(currentTherapist.id);
      }

      isFavorite = !isFavorite;

      isChangingFavorite = false;
      notifyListeners();

      return true;
    } catch (error) {
      isChangingFavorite = false;
      errorMessage = error.toString();
      notifyListeners();

      return false;
    }
  }
}
