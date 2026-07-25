import 'package:flutter/material.dart';

import '../../../../core/error/app_exception.dart';
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

  int _pageNumber = 1;

  List<ReviewModel> reviews = [];

  Future<void> loadReviews() async {
    isLoading = true;
    error = null;
    _pageNumber = 1;
    reviews = [];
    notifyListeners();

    try {
      final result = await repository.getMyReviews(
        pageNumber: 1,
        pageSize: _pageSize,
      );

      reviews = result.items;
      hasMore = result.hasMore;
    } catch (exception) {
      error = _getErrorMessage(exception);
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore) {
      return;
    }

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final nextPage = _pageNumber + 1;

      final result = await repository.getMyReviews(
        pageNumber: nextPage,
        pageSize: _pageSize,
      );

      reviews.addAll(result.items);
      _pageNumber = nextPage;
      hasMore = result.hasMore;
    } catch (exception) {
      error = _getErrorMessage(exception);
    }

    isLoadingMore = false;
    notifyListeners();
  }

  String _getErrorMessage(Object exception) {
    if (exception is AppException) {
      return exception.message;
    }

    return exception.toString();
  }
}
