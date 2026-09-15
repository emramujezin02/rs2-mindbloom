import '../models/therapist_recommendation_model.dart';
import '../models/therapist_recommendation_request.dart';
import '../services/recommendation_api_service.dart';

class RecommendationRepository {
  final RecommendationApiService apiService;

  RecommendationRepository({required this.apiService});

  Future<List<TherapistRecommendationModel>> getTherapistRecommendations(
    TherapistRecommendationRequest request,
  ) {
    return apiService.getTherapistRecommendations(request);
  }
}
