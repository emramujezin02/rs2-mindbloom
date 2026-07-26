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
          comment: comment,
        ),
      );

      return true;
    } catch (exception) {
      _setError(exception, fallback: 'Recenziju nije moguće sačuvati.');

      return false;
    } finally {}
  }

  Future<bool> updateReview({
    required int reviewId,
    required int rating,
    required String comment,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

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
        request: UpdateReviewRequest(rating: rating, comment: comment),
      );

      return true;
    } catch (exception) {
      _setError(exception, fallback: 'Recenziju nije moguće sačuvati.');

      return false;
    } finally {}
  }

  String _getErrorMessage(Object exception) {
    if (exception is AppException) {
      return exception.message;
    }

    return exception.toString();
  }

  Map<String, List<String>> fieldErrors = {};

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

  void _setError(Object exception, {required String fallback}) {
    if (exception is AppException) {
      error = exception.message.trim().isEmpty
          ? fallback
          : exception.message.trim();

      fieldErrors = Map<String, List<String>>.from(exception.fieldErrors);

      return;
    }

    final message = exception.toString().replaceFirst('Exception: ', '').trim();

    error = message.isEmpty ? fallback : message;
  }

  String _normalizeFieldName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  }
}
