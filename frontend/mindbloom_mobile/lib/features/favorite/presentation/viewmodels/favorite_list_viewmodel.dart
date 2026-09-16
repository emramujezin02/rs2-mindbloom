import 'package:flutter/foundation.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/favorite_model.dart';
import '../../data/repositories/favorite_repository.dart';

class FavoriteListViewModel extends ChangeNotifier {
  static const int pageSize = 10;

  final FavoriteRepository repository;

  FavoriteListViewModel({required this.repository});

  bool isLoading = false;
  bool isLoadingMore = false;
  bool isRemoving = false;

  int? removingTherapistId;

  String? errorMessage;
  String? loadMoreErrorMessage;

  List<FavoriteModel> favorites = [];

  int pageNumber = 1;
  int totalPages = 0;

  bool get hasMorePages => pageNumber < totalPages;

  Future<void> loadFavorites() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    loadMoreErrorMessage = null;
    pageNumber = 1;
    notifyListeners();

    try {
      final response = await repository.getMyFavorites(
        pageNumber: 1,
        pageSize: pageSize,
      );

      favorites = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
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

  Future<void> loadMoreFavorites() async {
    if (isLoading || isLoadingMore || !hasMorePages) {
      return;
    }

    isLoadingMore = true;
    loadMoreErrorMessage = null;
    notifyListeners();

    try {
      final response = await repository.getMyFavorites(
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
      );

      final existingIds =
          favorites.map((favorite) => favorite.therapistId).toSet();

      favorites.addAll(
        response.items.where(
          (favorite) => !existingIds.contains(favorite.therapistId),
        ),
      );

      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
    } catch (error) {
      loadMoreErrorMessage = AppErrorMessage.from(
        error,
        fallback: 'More favorites could not be loaded.',
      );
    } finally {
      isLoadingMore = false;
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
      if (favorites.isEmpty && pageNumber > 1) {
        await loadFavorites();
      }
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
