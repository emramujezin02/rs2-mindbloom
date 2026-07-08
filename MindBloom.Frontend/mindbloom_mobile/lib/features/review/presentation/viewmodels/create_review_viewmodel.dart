import 'package:flutter/material.dart';

import '../../data/models/create_review_request.dart';
import '../../data/repositories/review_repository.dart';

class CreateReviewViewModel extends ChangeNotifier {
  final ReviewRepository repository;

  CreateReviewViewModel({required this.repository});

  bool isLoading = false;
  String? error;

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
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();

      return false;
    }
  }
}
