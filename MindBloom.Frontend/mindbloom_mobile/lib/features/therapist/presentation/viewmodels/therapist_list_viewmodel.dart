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

  final Set<int> changingFavoriteTherapistIds = <int>{};

  TherapistListViewModel({
    required this.therapistRepository,
    required this.favoriteRepository,
  });

  Future<void> loadTherapists({int? therapyApproachId}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (therapyApproachId != null) {
        therapists = await therapistRepository.searchTherapists(
          TherapistFilterRequest(therapyApproachId: therapyApproachId),
        );
      } else {
        therapists = await therapistRepository.getTherapists();
      }

      await _tryLoadFavoriteIds();
    } catch (error) {
      errorMessage = _normalizeError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchTherapists({
    String? name,
    String? specialization,
    int? therapyApproachId,
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
          therapyApproachId: therapyApproachId,
          minPrice: minPrice,
          maxPrice: maxPrice,
          sortBy: sortBy,
        ),
      );

      await _tryLoadFavoriteIds();
    } catch (error) {
      errorMessage = _normalizeError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFavoriteIds() async {
    try {
      await _loadFavoriteIdsWithoutNotification();
    } catch (error) {
      errorMessage = _normalizeError(error);
    }

    notifyListeners();
  }

  Future<void> _loadFavoriteIdsWithoutNotification() async {
    final favorites = await favoriteRepository.getMyFavorites();

    favoriteTherapistIds
      ..clear()
      ..addAll(favorites.map((FavoriteModel favorite) => favorite.therapistId));
  }

  Future<void> _tryLoadFavoriteIds() async {
    try {
      await _loadFavoriteIdsWithoutNotification();
    } catch (_) {
      favoriteTherapistIds.clear();
    }
  }

  bool isFavorite(int therapistId) {
    return favoriteTherapistIds.contains(therapistId);
  }

  bool isChangingFavorite(int therapistId) {
    return changingFavoriteTherapistIds.contains(therapistId);
  }

  Future<bool> toggleFavorite(int therapistId) async {
    if (isChangingFavorite(therapistId)) {
      return false;
    }

    errorMessage = null;
    changingFavoriteTherapistIds.add(therapistId);
    notifyListeners();

    try {
      if (isFavorite(therapistId)) {
        await favoriteRepository.removeFavorite(therapistId);
        favoriteTherapistIds.remove(therapistId);
      } else {
        await favoriteRepository.addFavorite(therapistId);
        favoriteTherapistIds.add(therapistId);
      }

      return true;
    } catch (error) {
      errorMessage = _normalizeError(error);
      return false;
    } finally {
      changingFavoriteTherapistIds.remove(therapistId);
      notifyListeners();
    }
  }

  String _normalizeError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }
}
