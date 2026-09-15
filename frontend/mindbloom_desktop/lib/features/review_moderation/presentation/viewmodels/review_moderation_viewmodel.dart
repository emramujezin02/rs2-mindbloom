import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/app_error_helper.dart';
import '../../data/models/admin_review_model.dart';
import '../../data/repositories/review_moderation_repository.dart';

class ReviewModerationViewModel extends ChangeNotifier {
  final ReviewModerationRepository repository;

  ReviewModerationViewModel({required this.repository});

  Timer? _searchDebounce;

  bool isLoading = false;

  String? errorMessage;

  List<AdminReviewModel> reviews = [];

  int pageNumber = 1;

  int pageSize = 10;

  int totalCount = 0;

  int totalPages = 0;

  String currentSearch = '';

  int? currentRating;

  int? currentTherapistId;

  int? currentStatus;

  bool? currentHasReply;

  bool get hasPreviousPage => pageNumber > 1;

  bool get hasNextPage => pageNumber < totalPages;

  Future<void> load({int? page, bool clearCurrentResults = false}) async {
    if (isLoading) {
      return;
    }

    isLoading = true;

    errorMessage = null;

    if (clearCurrentResults) {
      reviews = [];

      totalCount = 0;

      totalPages = 0;
    }

    notifyListeners();

    try {
      final result = await repository.getReviews(
        pageNumber: page ?? pageNumber,
        pageSize: pageSize,
        search: currentSearch,
        rating: currentRating,
        therapistId: currentTherapistId,
        status: currentStatus,
        hasTherapistReply: currentHasReply,
      );

      reviews = result.items;

      pageNumber = result.pageNumber == 0 ? 1 : result.pageNumber;

      pageSize = result.pageSize == 0 ? pageSize : result.pageSize;

      totalCount = result.totalCount;

      totalPages = result.totalPages;
    } catch (error) {
      reviews = [];

      totalCount = 0;

      totalPages = 0;

      errorMessage = AppErrorHelper.message(error);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  void updateSearch(String value) {
    currentSearch = value.trim();

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      load(page: 1, clearCurrentResults: true);
    });
  }

  Future<void> applyFilters({
    required String search,
    int? rating,
    int? therapistId,
    int? status,
    bool? hasReply,
  }) {
    _searchDebounce?.cancel();

    currentSearch = search.trim();

    currentRating = rating;

    currentTherapistId = therapistId;

    currentStatus = status;

    currentHasReply = hasReply;

    return load(page: 1, clearCurrentResults: true);
  }

  Future<void> clearFilters() {
    _searchDebounce?.cancel();

    currentSearch = '';
    currentRating = null;
    currentTherapistId = null;
    currentStatus = null;
    currentHasReply = null;

    return load(page: 1, clearCurrentResults: true);
  }

  Future<void> previousPage() {
    if (!hasPreviousPage || isLoading) {
      return Future.value();
    }

    return load(page: pageNumber - 1);
  }

  Future<void> nextPage() {
    if (!hasNextPage || isLoading) {
      return Future.value();
    }

    return load(page: pageNumber + 1);
  }

  Future<void> changePageSize(int value) {
    if (pageSize == value) {
      return Future.value();
    }

    pageSize = value;

    return load(page: 1, clearCurrentResults: true);
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    errorMessage = null;

    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    super.dispose();
  }
}
