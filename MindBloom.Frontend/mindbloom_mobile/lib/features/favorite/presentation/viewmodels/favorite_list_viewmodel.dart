import 'package:flutter/foundation.dart';

import '../../data/models/favorite_model.dart';
import '../../data/repositories/favorite_repository.dart';

class FavoriteListViewModel extends ChangeNotifier {
  final FavoriteRepository repository;

  FavoriteListViewModel({required this.repository});

  bool isLoading = false;
  String? errorMessage;

  List<FavoriteModel> favorites = [];

  Future<void> loadFavorites() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      favorites = await repository.getMyFavorites();
    } catch (error) {
      errorMessage = error.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> removeFavorite(int therapistId) async {
    errorMessage = null;
    notifyListeners();

    try {
      await repository.removeFavorite(therapistId);

      favorites.removeWhere((favorite) => favorite.therapistId == therapistId);

      notifyListeners();

      return true;
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();

      return false;
    }
  }
}
