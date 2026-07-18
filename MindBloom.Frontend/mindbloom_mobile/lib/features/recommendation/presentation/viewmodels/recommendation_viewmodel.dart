import 'package:flutter/material.dart';

import '../../data/models/therapist_recommendation_model.dart';
import '../../data/models/therapist_recommendation_request.dart';
import '../../data/repositories/recommendation_repository.dart';

class RecommendationViewModel extends ChangeNotifier {
  final RecommendationRepository repository;

  RecommendationViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  List<TherapistRecommendationModel> recommendations = [];

  TherapistRecommendationRequest currentRequest =
      const TherapistRecommendationRequest();

  Future<void> loadRecommendations({
    TherapistRecommendationRequest request =
        const TherapistRecommendationRequest(),
  }) async {
    isLoading = true;
    error = null;
    currentRequest = request;

    notifyListeners();

    try {
      recommendations = await repository.getTherapistRecommendations(request);
    } catch (exception) {
      error = exception.toString();
      recommendations = [];
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadRecommendations(request: currentRequest);
  }
}
