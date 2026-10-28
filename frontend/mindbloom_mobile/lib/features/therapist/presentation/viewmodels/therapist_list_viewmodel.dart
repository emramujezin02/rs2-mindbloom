import 'package:flutter/foundation.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../../favorite/data/repositories/favorite_repository.dart';
import '../../data/models/therapist_filter_request.dart';
import '../../data/models/therapist_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistListViewModel extends ChangeNotifier {
  List<Map<String, dynamic>> therapyApproaches = [], specializations = [];
  bool isLoadingOptions = false;
  String? optionsError;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadFilterOptions() async {
    if (isLoadingOptions) return;
    isLoadingOptions = true;
    optionsError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        therapistRepository.getFilterOptions('therapy-approaches'),
        therapistRepository.getFilterOptions('therapist-specializations'),
      ]);
      therapyApproaches = results[0];
      specializations = results[1];
    } catch (_) {
      optionsError = 'Filtere nije moguće učitati.';
    } finally {
      isLoadingOptions = false;
      if (!_disposed) notifyListeners();
    }
  }

  final TherapistRepository therapistRepository;
  final FavoriteRepository favoriteRepository;

  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;

  String? errorMessage;
  String? loadMoreErrorMessage;
  String? favoriteErrorMessage;

  List<TherapistModel> therapists = [];

  final Set<int> favoriteTherapistIds = <int>{};
  final Set<int> changingFavoriteTherapistIds = <int>{};

  int currentPage = 1;
  final int pageSize = 10;

  TherapistFilterRequest _activeRequest = const TherapistFilterRequest();
  TherapistFilterRequest? _pendingRequest;

  TherapistListViewModel({
    required this.therapistRepository,
    required this.favoriteRepository,
  });

  Future<void> loadTherapists({int? therapyApproachId}) async {
    await searchTherapists(
      therapyApproachId: therapyApproachId,
      resetPage: true,
    );
  }

  Future<void> refresh() async {
    await _loadFirstPage(
      _activeRequest.copyWith(pageNumber: 1, pageSize: pageSize),
    );
  }

  Future<void> searchTherapists({
    int? locationId,
    int? minExperienceYears,
    int? maxExperienceYears,
    bool offersOnline = false,
    bool worksWithChildren = false,
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
    String? sortDirection,
    bool resetPage = true,
  }) async {
    final requestedPage = resetPage ? 1 : currentPage;

    final request = TherapistFilterRequest(
      locationId: locationId,
      minExperienceYears: minExperienceYears,
      maxExperienceYears: maxExperienceYears,
      offersOnline: offersOnline,
      worksWithChildren: worksWithChildren,
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
      sortDirection: sortDirection,
      pageNumber: requestedPage,
      pageSize: pageSize,
    );

    if (isLoading || isLoadingMore) {
      _pendingRequest = request;
      return;
    }
    await _loadFirstPage(request);
  }

  Future<void> _loadFirstPage(TherapistFilterRequest request) async {
    if (isLoading || isLoadingMore) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    loadMoreErrorMessage = null;
    favoriteErrorMessage = null;
    notifyListeners();

    try {
      final page = await therapistRepository.searchTherapists(request);

      therapists = _removeDuplicates(page.items);
      currentPage = page.pageNumber;
      hasMore = page.hasMore;
      _activeRequest = request.copyWith(
        pageNumber: page.pageNumber,
        pageSize: pageSize,
      );

      await _tryLoadFavoriteIds();

      errorMessage = null;
    } catch (error) {
      errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Therapists could not be loaded.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
      await _loadPendingRequest();
    }
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !hasMore || therapists.isEmpty) {
      return;
    }

    isLoadingMore = true;
    loadMoreErrorMessage = null;
    notifyListeners();

    final nextPage = currentPage + 1;
    final nextRequest = _activeRequest.copyWith(
      pageNumber: nextPage,
      pageSize: pageSize,
    );

    try {
      final page = await therapistRepository.searchTherapists(nextRequest);

      final merged = <int, TherapistModel>{
        for (final therapist in therapists) therapist.id: therapist,
        for (final therapist in page.items) therapist.id: therapist,
      };

      therapists = merged.values.toList();
      currentPage = page.pageNumber;
      hasMore = page.hasMore;
      _activeRequest = nextRequest.copyWith(
        pageNumber: page.pageNumber,
        pageSize: pageSize,
      );

      await _tryLoadFavoriteIds();

      loadMoreErrorMessage = null;
    } catch (error) {
      loadMoreErrorMessage = AppErrorMessage.from(
        error,
        fallback: 'More therapists could not be loaded.',
      );
    } finally {
      isLoadingMore = false;
      notifyListeners();
      await _loadPendingRequest();
    }
  }

  Future<void> retryLoadMore() async {
    await loadMore();
  }

  Future<void> _loadPendingRequest() async {
    final request = _pendingRequest;
    _pendingRequest = null;
    if (request != null && !_disposed) await _loadFirstPage(request);
  }

  List<TherapistModel> _removeDuplicates(List<TherapistModel> items) {
    final unique = <int, TherapistModel>{};

    for (final therapist in items) {
      unique[therapist.id] = therapist;
    }

    return unique.values.toList();
  }

  Future<void> loadFavoriteIds() async {
    favoriteErrorMessage = null;

    try {
      await _loadFavoriteIdsWithoutNotification();
    } catch (error) {
      favoriteErrorMessage = AppErrorMessage.from(
        error,
        fallback: 'Favorites could not be loaded.',
      );
    }

    notifyListeners();
  }

  Future<void> _loadFavoriteIdsWithoutNotification() async {
    final loadedTherapistIds = therapists
        .map((therapist) => therapist.id)
        .toSet();

    final favoriteChecks = await Future.wait(
      loadedTherapistIds.map((therapistId) async {
        final isFavorite = await favoriteRepository.isFavorite(therapistId);

        return (therapistId, isFavorite);
      }),
    );

    favoriteTherapistIds
      ..clear()
      ..addAll(
        favoriteChecks.where((check) => check.$2).map((check) => check.$1),
      );
  }

  Future<void> _tryLoadFavoriteIds() async {
    try {
      await _loadFavoriteIdsWithoutNotification();
      favoriteErrorMessage = null;
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

    favoriteErrorMessage = null;
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

      favoriteErrorMessage = null;
      return true;
    } catch (error) {
      favoriteErrorMessage = AppErrorMessage.from(
        error,
        fallback: 'Favorite could not be updated.',
      );
      return false;
    } finally {
      changingFavoriteTherapistIds.remove(therapistId);
      notifyListeners();
    }
  }
}
