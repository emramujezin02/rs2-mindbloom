import 'package:flutter/foundation.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/favorite_model.dart';
import '../../data/repositories/favorite_repository.dart';

class FavoriteListViewModel extends ChangeNotifier {
  final FavoriteRepository repository;

  FavoriteListViewModel({required this.repository});

  bool isLoading = false;
  bool isRemoving = false;

  int? removingTherapistId;

  String? errorMessage;

  List<FavoriteModel> favorites = [];

  Future<void> loadFavorites() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      favorites = await repository.getMyFavorites();
      errorMessage = null;
    } catch (error) {
      errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Omiljene terapeute nije moguće učitati.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeFavorite(int therapistId) async {
    if (isRemoving) {
      return false;
    }

    isRemoving = true;
    removingTherapistId = therapistId;
    errorMessage = null;
    notifyListeners();

    try {
      await repository.removeFavorite(therapistId);

      favorites.removeWhere((favorite) => favorite.therapistId == therapistId);
      errorMessage = null;
      return true;
    } catch (error) {
      errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Terapeuta nije moguće ukloniti iz omiljenih.',
      );
      return false;
    } finally {
      isRemoving = false;
      removingTherapistId = null;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadFavorites();

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }
}
