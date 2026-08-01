import 'package:flutter/foundation.dart';

import '../../data/models/admin_review_model.dart';
import '../../data/repositories/review_moderation_repository.dart';

class ReviewModerationViewModel extends ChangeNotifier {
  final ReviewModerationRepository repository;

  ReviewModerationViewModel({required this.repository});

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

  Future<void> load({int? page}) async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;

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
      errorMessage = _cleanError(error);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<void> applyFilters({
    required String search,
    int? rating,
    int? therapistId,
    int? status,
    bool? hasReply,
  }) {
    currentSearch = search.trim();

    currentRating = rating;

    currentTherapistId = therapistId;

    currentStatus = status;

    currentHasReply = hasReply;

    return load(page: 1);
  }

  Future<void> clearFilters() {
    currentSearch = '';

    currentRating = null;

    currentTherapistId = null;

    currentStatus = null;

    currentHasReply = null;

    return load(page: 1);
  }

  Future<void> previousPage() {
    if (!hasPreviousPage) {
      return Future.value();
    }

    return load(page: pageNumber - 1);
  }

  Future<void> nextPage() {
    if (!hasNextPage) {
      return Future.value();
    }

    return load(page: pageNumber + 1);
  }

  Future<void> changePageSize(int value) {
    pageSize = value;

    return load(page: 1);
  }

  String _cleanError(Object error) {
    final value = error.toString();

    if (value.startsWith('Exception: ')) {
      return value.substring('Exception: '.length);
    }

    return value;
  }
}
