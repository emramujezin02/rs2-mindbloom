import 'package:flutter/material.dart';

import '../../data/models/review_model.dart';
import '../../data/repositories/review_repository.dart';

class MyReviewsViewModel extends ChangeNotifier {
  final ReviewRepository repository;

  MyReviewsViewModel({required this.repository});

  bool isLoading = false;
  String? error;

  List<ReviewModel> reviews = [];

  Future<void> loadReviews() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      reviews = await repository.getMyReviews();
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }
}
