import '../../../../core/network/api_client.dart';
import '../models/review_model.dart';
import '../models/create_review_request.dart';

class ReviewApiService {
  final ApiClient apiClient;

  ReviewApiService({required this.apiClient});

  Future<List<ReviewModel>> getTherapistReviews(int therapistId) async {
    final response = await apiClient.get('/Reviews/therapist/$therapistId');

    return (response as List).map((e) => ReviewModel.fromJson(e)).toList();
  }

  Future<void> createReview(CreateReviewRequest request) async {
    await apiClient.post('/Reviews', body: request.toJson());
  }

  Future<List<ReviewModel>> getMyReviews() async {
    final response = await apiClient.get('/Reviews/mine');

    return (response as List)
        .map((item) => ReviewModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
