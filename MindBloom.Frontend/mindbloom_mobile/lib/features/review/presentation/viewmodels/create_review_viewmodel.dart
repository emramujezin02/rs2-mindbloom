import 'package:flutter/material.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/widgets/app_error_message.dart';
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

  Map<String, List<String>> fieldErrors = {};

  Future<void> checkEligibility(int appointmentId) async {
    if (isCheckingEligibility) {
      return;
    }

    isCheckingEligibility = true;
    error = null;
    notifyListeners();

    try {
      eligibility = await repository.getEligibility(appointmentId);
      error = null;
    } catch (exception) {
      error = AppErrorMessage.from(
        exception,
        fallback: 'Mogućnost ostavljanja recenzije nije moguće provjeriti.',
      );
    } finally {
      isCheckingEligibility = false;
      notifyListeners();
    }
  }

  Future<bool> createReview({
    required int appointmentId,
    required int rating,
    required String comment,
  }) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;
    error = null;
    fieldErrors = {};
    notifyListeners();

    try {
      await repository.createReview(
        CreateReviewRequest(
          appointmentId: appointmentId,
          rating: rating,
          comment: comment.trim(),
        ),
      );

      error = null;
      return true;
    } catch (exception) {
      _setError(exception, fallback: 'Recenziju nije moguće sačuvati.');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateReview({
    required int reviewId,
    required int rating,
    required String comment,
  }) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;
    error = null;
    fieldErrors = {};
    notifyListeners();

    try {
      await repository.updateReview(
        reviewId: reviewId,
        request: UpdateReviewRequest(rating: rating, comment: comment.trim()),
      );

      error = null;
      return true;
    } catch (exception) {
      _setError(exception, fallback: 'Recenziju nije moguće sačuvati.');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String? fieldError(String fieldName) {
    final requested = _normalizeFieldName(fieldName);

    for (final entry in fieldErrors.entries) {
      if (_normalizeFieldName(entry.key) == requested &&
          entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }

    return null;
  }

  void clearError() {
    if (error == null && fieldErrors.isEmpty) {
      return;
    }

    error = null;
    fieldErrors = {};
    notifyListeners();
  }

  void _setError(Object exception, {required String fallback}) {
    if (exception is AppException) {
      error = exception.message.trim().isEmpty
          ? fallback
          : exception.message.trim();

      fieldErrors = Map<String, List<String>>.from(exception.fieldErrors);
      return;
    }

    fieldErrors = {};
    error = AppErrorMessage.from(exception, fallback: fallback);
  }

  String _normalizeFieldName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  }
}
