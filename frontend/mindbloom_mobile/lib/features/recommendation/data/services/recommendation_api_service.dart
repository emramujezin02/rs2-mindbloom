import '../../../../core/network/api_client.dart';
import '../models/therapist_recommendation_model.dart';
import '../models/therapist_recommendation_request.dart';

class RecommendationApiService {
  final ApiClient apiClient;

  RecommendationApiService({required this.apiClient});

  Future<List<TherapistRecommendationModel>> getTherapistRecommendations(
    TherapistRecommendationRequest request,
  ) async {
    final response = await apiClient.post(
      '/recommendations/therapists',
      body: request.toJson(),
    );

    return (response as List)
        .map(
          (item) => TherapistRecommendationModel.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}
