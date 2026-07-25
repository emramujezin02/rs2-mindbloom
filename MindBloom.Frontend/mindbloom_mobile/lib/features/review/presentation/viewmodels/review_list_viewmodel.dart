import 'package:flutter/material.dart';
import 'package:mindbloom_mobile/features/review/data/models/review_page_result.dart';

import '../../../../core/error/app_exception.dart';
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

  int _pageNumber = 1;

  List<ReviewModel> reviews = [];

  TherapistRatingModel? rating;

  Future<void> loadReviews(int therapistId) async {
    isLoading = true;
    error = null;
    _pageNumber = 1;
    reviews = [];
    notifyListeners();

    try {
      final results = await Future.wait([
        repository.getTherapistReviews(
          therapistId: therapistId,
          pageNumber: 1,
          pageSize: _pageSize,
        ),
        repository.getTherapistRating(therapistId),
      ]);

      final page = results[0] as ReviewPageResult;

      reviews = page.items;
      hasMore = page.hasMore;

      rating = results[1] as TherapistRatingModel;
    } catch (exception) {
      error = _getErrorMessage(exception);
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore(int therapistId) async {
    if (isLoadingMore || !hasMore) {
      return;
    }

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final nextPage = _pageNumber + 1;

      final result = await repository.getTherapistReviews(
        therapistId: therapistId,
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
