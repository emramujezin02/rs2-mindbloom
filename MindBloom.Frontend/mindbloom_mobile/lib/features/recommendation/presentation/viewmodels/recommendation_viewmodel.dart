import 'package:flutter/material.dart';

import '../../../../core/widgets/app_error_message.dart';
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
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;
    currentRequest = request;

    notifyListeners();

    try {
      final loadedRecommendations = await repository
          .getTherapistRecommendations(request);

      loadedRecommendations.sort((first, second) {
        final scoreComparison = second.score.compareTo(first.score);

        if (scoreComparison != 0) {
          return scoreComparison;
        }

        final percentageComparison = second.matchPercentage.compareTo(
          first.matchPercentage,
        );

        if (percentageComparison != 0) {
          return percentageComparison;
        }

        return second.averageRating.compareTo(first.averageRating);
      });

      recommendations = loadedRecommendations;

      error = null;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() {
    return loadRecommendations(request: currentRequest);
  }

  void clearError() {
    if (error == null) {
      return;
    }

    error = null;
    notifyListeners();
  }
}
