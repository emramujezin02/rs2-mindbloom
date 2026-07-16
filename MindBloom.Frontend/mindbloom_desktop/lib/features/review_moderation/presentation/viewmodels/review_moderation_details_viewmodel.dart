import 'package:flutter/foundation.dart';

import '../../data/models/admin_review_details_model.dart';
import '../../data/repositories/review_moderation_repository.dart';

class ReviewModerationDetailsViewModel extends ChangeNotifier {
  final ReviewModerationRepository repository;

  ReviewModerationDetailsViewModel({required this.repository});

  bool isLoading = false;

  bool isDeleting = false;

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

  Future<bool> deleteReview({
    required int reviewId,
    required String reason,
  }) async {
    if (isDeleting) {
      return false;
    }

    isDeleting = true;
    errorMessage = null;
    notifyListeners();

    try {
      await repository.deleteReview(reviewId: reviewId, reason: reason);

      await load(reviewId);

      return true;
    } catch (error) {
      errorMessage = _cleanError(error);

      return false;
    } finally {
      isDeleting = false;
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
