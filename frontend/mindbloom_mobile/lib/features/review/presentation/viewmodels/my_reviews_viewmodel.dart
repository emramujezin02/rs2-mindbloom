import 'package:flutter/material.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/review_model.dart';
import '../../data/repositories/review_repository.dart';

class MyReviewsViewModel extends ChangeNotifier {
  final ReviewRepository repository;

  MyReviewsViewModel({required this.repository});

  static const int _pageSize = 10;

  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;

  String? error;
  String? loadMoreError;

  int _pageNumber = 1;

  List<ReviewModel> reviews = [];

  Future<void> loadReviews() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;
    loadMoreError = null;
    notifyListeners();

    try {
      final result = await repository.getMyReviews(
        pageNumber: 1,
        pageSize: _pageSize,
      );

      reviews = result.items;
      _pageNumber = 1;
      hasMore = result.hasMore;

      error = null;
      loadMoreError = null;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore || isLoading || !hasMore) {
      return;
    }

    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();

    try {
      final nextPage = _pageNumber + 1;

      final result = await repository.getMyReviews(
        pageNumber: nextPage,
        pageSize: _pageSize,
      );

      final existingReviewIds = reviews.map((review) => review.id).toSet();

      final newReviews = result.items
          .where((review) => !existingReviewIds.contains(review.id))
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

  Future<void> retryLoadMore() {
    return loadMore();
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
