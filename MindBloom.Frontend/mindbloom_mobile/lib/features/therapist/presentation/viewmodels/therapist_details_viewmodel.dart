import 'package:flutter/foundation.dart';

import '../../../../core/widgets/app_error_message.dart';
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
  String? favoriteErrorMessage;

  TherapistDetailsModel? therapist;
  bool isFavorite = false;

  Future<void> loadTherapist(int therapistId) async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    favoriteErrorMessage = null;
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

      errorMessage = null;
    } catch (error) {
      errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Podatke o terapeutu nije moguće učitati.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleFavorite() async {
    final currentTherapist = therapist;

    if (currentTherapist == null || isChangingFavorite) {
      return false;
    }

    isChangingFavorite = true;
    favoriteErrorMessage = null;
    notifyListeners();

    try {
      if (isFavorite) {
        await favoriteRepository.removeFavorite(currentTherapist.id);
      } else {
        await favoriteRepository.addFavorite(currentTherapist.id);
      }

      isFavorite = !isFavorite;
      favoriteErrorMessage = null;
      return true;
    } catch (error) {
      favoriteErrorMessage = AppErrorMessage.from(
        error,
        fallback: 'Omiljeni status nije moguće promijeniti.',
      );
      return false;
    } finally {
      isChangingFavorite = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final therapistId = therapist?.id;
    if (therapistId == null) return;
    await loadTherapist(therapistId);
  }

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  void clearFavoriteError() {
    if (favoriteErrorMessage == null) return;
    favoriteErrorMessage = null;
    notifyListeners();
  }
}
