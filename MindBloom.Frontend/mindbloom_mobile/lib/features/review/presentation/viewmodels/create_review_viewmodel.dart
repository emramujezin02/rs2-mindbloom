import 'package:flutter/material.dart';

import '../../../../core/error/app_exception.dart';
import '../../data/models/create_review_request.dart';
import '../../data/models/review_eligibility_model.dart';
import '../../data/models/update_review_request.dart';
import '../../data/repositories/review_repository.dart';

class CreateReviewViewModel extends ChangeNotifier {
  final ReviewRepository repository;

  CreateReviewViewModel({required this.repository});

  bool isLoading = false;
  bool isCheckingEligibility = false;

  String? error;

  ReviewEligibilityModel? eligibility;

  Future<void> checkEligibility(int appointmentId) async {
    isCheckingEligibility = true;
    error = null;
    notifyListeners();

    try {
      eligibility = await repository.getEligibility(appointmentId);
    } catch (exception) {
      error = _getErrorMessage(exception);
    }

    isCheckingEligibility = false;
    notifyListeners();
  }

  Future<bool> createReview({
    required int appointmentId,
    required int rating,
    required String comment,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await repository.createReview(
        CreateReviewRequest(
          appointmentId: appointmentId,
          rating: rating,
          comment: comment,
        ),
      );

      isLoading = false;
      notifyListeners();

      return true;
    } catch (exception) {
      error = _getErrorMessage(exception);
      isLoading = false;
      notifyListeners();

      return false;
    }
  }

  Future<bool> updateReview({
    required int reviewId,
    required int rating,
    required String comment,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await repository.updateReview(
        reviewId: reviewId,
        request: UpdateReviewRequest(rating: rating, comment: comment),
      );

      isLoading = false;
      notifyListeners();

      return true;
    } catch (exception) {
      error = _getErrorMessage(exception);
      isLoading = false;
      notifyListeners();

      return false;
    }
  }

  String _getErrorMessage(Object exception) {
    if (exception is AppException) {
      return exception.message;
    }

    return exception.toString();
  }
}
