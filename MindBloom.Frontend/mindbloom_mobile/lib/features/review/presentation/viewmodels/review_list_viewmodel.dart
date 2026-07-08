import 'package:flutter/material.dart';

import '../../data/models/review_model.dart';
import '../../data/repositories/review_repository.dart';

class ReviewListViewModel extends ChangeNotifier {
  final ReviewRepository repository;

  ReviewListViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  List<ReviewModel> reviews = [];

  Future<void> loadReviews(int therapistId) async {
    isLoading = true;
    notifyListeners();

    try {
      reviews = await repository.getTherapistReviews(therapistId);
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }
}
