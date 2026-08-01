import 'package:flutter/foundation.dart';

import '../../data/models/admin_review_details_model.dart';
import '../../data/repositories/review_moderation_repository.dart';

class ReviewModerationDetailsViewModel extends ChangeNotifier {
  final ReviewModerationRepository repository;

  ReviewModerationDetailsViewModel({required this.repository});

  bool isLoading = false;

  bool isProcessing = false;

  String? errorMessage;

  AdminReviewDetailsModel? review;

  Future<void> load(int reviewId) async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      review = await repository.getDetails(reviewId);
    } catch (error) {
      errorMessage = _cleanError(error);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> approveReview(int reviewId) async {
    return _runAction(
      reviewId: reviewId,
      action: () {
        return repository.approveReview(reviewId);
      },
    );
  }

  Future<bool> rejectReview({
    required int reviewId,
    required String reason,
  }) async {
    return _runAction(
      reviewId: reviewId,
      action: () {
        return repository.rejectReview(reviewId: reviewId, reason: reason);
      },
    );
  }

  Future<bool> hideReview({
    required int reviewId,
    required String reason,
  }) async {
    return _runAction(
      reviewId: reviewId,
      action: () {
        return repository.hideReview(reviewId: reviewId, reason: reason);
      },
    );
  }

  Future<bool> deleteReview({
    required int reviewId,
    required String reason,
  }) async {
    return _runAction(
      reviewId: reviewId,
      action: () {
        return repository.deleteReview(reviewId: reviewId, reason: reason);
      },
    );
  }

  Future<bool> _runAction({
    required int reviewId,
    required Future<void> Function() action,
  }) async {
    if (isProcessing) {
      return false;
    }

    isProcessing = true;
    errorMessage = null;

    notifyListeners();

    try {
      await action();

      review = await repository.getDetails(reviewId);

      return true;
    } catch (error) {
      errorMessage = _cleanError(error);

      return false;
    } finally {
      isProcessing = false;

      notifyListeners();
    }
  }

  String _cleanError(Object error) {
    final value = error.toString();

    if (value.startsWith('Exception: ')) {
      return value.substring('Exception: '.length);
    }

    return value;
  }
}
