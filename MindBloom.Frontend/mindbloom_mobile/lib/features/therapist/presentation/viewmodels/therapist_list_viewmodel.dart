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
  bool isLoadingMore = false;
  bool hasMore = true;
  String? errorMessage;

  List<TherapistModel> therapists = [];

  final Set<int> favoriteTherapistIds = <int>{};
  final Set<int> changingFavoriteTherapistIds =
      <int>{};

  int currentPage = 1;
  final int pageSize = 10;

  TherapistFilterRequest _activeRequest =
      const TherapistFilterRequest();

  TherapistListViewModel({
    required this.therapistRepository,
    required this.favoriteRepository,
  });

  Future<void> loadTherapists({
    int? therapyApproachId,
  }) async {
    await searchTherapists(
      therapyApproachId: therapyApproachId,
      resetPage: true,
    );
  }

  Future<void> searchTherapists({
    String? searchText,
    String? specialization,
    int? therapyApproachId,
    String? gender,
    String? language,
    String? location,
    String? sessionMode,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String? availableDay,
    String? sortBy,
    bool resetPage = true,
  }) async {
    if (isLoading || isLoadingMore) {
      return;
    }

    if (resetPage) {
      currentPage = 1;
      hasMore = true;
    }

    _activeRequest = TherapistFilterRequest(
      searchText: searchText,
      specialization: specialization,
      therapyApproachId: therapyApproachId,
      gender: gender,
      language: language,
      location: location,
      sessionMode: sessionMode,
      minPrice: minPrice,
      maxPrice: maxPrice,
      minRating: minRating,
      availableDay: availableDay,
      sortBy: sortBy,
      pageNumber: currentPage,
      pageSize: pageSize,
    );

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final page =
          await therapistRepository.searchTherapists(
        _activeRequest,
      );

      therapists = _removeDuplicates(page.items);
      currentPage = page.pageNumber;
      hasMore = page.hasMore;

      await _tryLoadFavoriteIds();
    } catch (error) {
      errorMessage = _normalizeError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoading ||
        isLoadingMore ||
        !hasMore ||
        therapists.isEmpty) {
      return;
    }

    isLoadingMore = true;
    errorMessage = null;
    notifyListeners();

    final nextPage = currentPage + 1;
    final nextRequest = _activeRequest.copyWith(
      pageNumber: nextPage,
      pageSize: pageSize,
    );

    try {
      final page =
          await therapistRepository.searchTherapists(
        nextRequest,
      );

      final merged = <int, TherapistModel>{
        for (final therapist in therapists)
          therapist.id: therapist,
        for (final therapist in page.items)
          therapist.id: therapist,
      };

      therapists = merged.values.toList();
      currentPage = page.pageNumber;
      hasMore = page.hasMore;
      _activeRequest = nextRequest;
    } catch (error) {
      errorMessage = _normalizeError(error);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  List<TherapistModel> _removeDuplicates(
    List<TherapistModel> items,
  ) {
    final unique = <int, TherapistModel>{};

    for (final therapist in items) {
      unique[therapist.id] = therapist;
    }

    return unique.values.toList();
  }

  Future<void> loadFavoriteIds() async {
    try {
      await _loadFavoriteIdsWithoutNotification();
    } catch (error) {
      errorMessage = _normalizeError(error);
    }

    notifyListeners();
  }

  Future<void> _loadFavoriteIdsWithoutNotification()
      async {
    final favorites =
        await favoriteRepository.getMyFavorites();

    favoriteTherapistIds
      ..clear()
      ..addAll(
        favorites.map(
          (FavoriteModel favorite) =>
              favorite.therapistId,
        ),
      );
  }

  Future<void> _tryLoadFavoriteIds() async {
    try {
      await _loadFavoriteIdsWithoutNotification();
    } catch (_) {
      favoriteTherapistIds.clear();
    }
  }

  bool isFavorite(int therapistId) {
    return favoriteTherapistIds.contains(
      therapistId,
    );
  }

  bool isChangingFavorite(int therapistId) {
    return changingFavoriteTherapistIds.contains(
      therapistId,
    );
  }

  Future<bool> toggleFavorite(
    int therapistId,
  ) async {
    if (isChangingFavorite(therapistId)) {
      return false;
    }

    errorMessage = null;

    changingFavoriteTherapistIds.add(
      therapistId,
    );

    notifyListeners();

    try {
      if (isFavorite(therapistId)) {
        await favoriteRepository.removeFavorite(
          therapistId,
        );

        favoriteTherapistIds.remove(
          therapistId,
        );
      } else {
        await favoriteRepository.addFavorite(
          therapistId,
        );

        favoriteTherapistIds.add(
          therapistId,
        );
      }

      return true;
    } catch (error) {
      errorMessage = _normalizeError(error);
      return false;
    } finally {
      changingFavoriteTherapistIds.remove(
        therapistId,
      );

      notifyListeners();
    }
  }

  String _normalizeError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }
}
