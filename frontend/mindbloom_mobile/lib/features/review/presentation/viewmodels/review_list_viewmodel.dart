import 'package:flutter/material.dart';
import 'package:mindbloom_mobile/features/review/data/models/review_page_result.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/review_model.dart';
import '../../data/models/therapist_rating_model.dart';
import '../../data/repositories/review_repository.dart';

class ReviewListViewModel extends ChangeNotifier {
  final ReviewRepository repository;

  ReviewListViewModel({required this.repository});

  static const int _pageSize = 10;

  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;

  String? error;
  String? loadMoreError;

  int _pageNumber = 1;

  List<ReviewModel> reviews = [];

  TherapistRatingModel? rating;

  Future<void> loadReviews(int therapistId) async {
    isLoading = true;
    error = null;
    loadMoreError = null;
    _pageNumber = 1;
    notifyListeners();

    try {
      final results = await Future.wait<Object>([
        repository.getTherapistReviews(
          therapistId: therapistId,
          pageNumber: 1,
          pageSize: _pageSize,
        ),
        repository.getTherapistRating(therapistId),
      ]);

      final page = results[0] as ReviewPageResult;

      final loadedRating = results[1] as TherapistRatingModel;

      reviews = page.items;
      rating = loadedRating;
      hasMore = page.hasMore;
      _pageNumber = 1;

      error = null;
      loadMoreError = null;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore(int therapistId) async {
    if (isLoadingMore || !hasMore) {
      return;
    }

    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();

    try {
      final nextPage = _pageNumber + 1;

      final result = await repository.getTherapistReviews(
        therapistId: therapistId,
        pageNumber: nextPage,
        pageSize: _pageSize,
      );

      final existingIds = reviews.map((review) => review.id).toSet();

      final newReviews = result.items
          .where((review) => !existingIds.contains(review.id))
          .toList();

      reviews.addAll(newReviews);

      _pageNumber = nextPage;
      hasMore = result.hasMore;

      loadMoreError = null;
    } catch (exception) {
      loadMoreError = AppErrorMessage.from(exception);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> retryLoadMore(int therapistId) {
    return loadMore(therapistId);
  }

  void clearError() {
    if (error == null) {
      return;
    }

    error = null;
    notifyListeners();
  }

  void clearLoadMoreError() {
    if (loadMoreError == null) {
      return;
    }

    loadMoreError = null;
    notifyListeners();
  }
}
