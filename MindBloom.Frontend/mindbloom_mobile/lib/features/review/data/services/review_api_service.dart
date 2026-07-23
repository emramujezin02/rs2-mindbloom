import '../../../../core/network/api_client.dart';
import '../models/review_model.dart';
import '../models/create_review_request.dart';

class ReviewApiService {
  final ApiClient apiClient;

  ReviewApiService({required this.apiClient});

  Future<List<ReviewModel>> getPublicReviews({int limit = 6}) async {
    final response = await apiClient.get(
      '/Reviews/public?limit=$limit',
      requiresAuth: false,
    );

    return _parseReviews(response);
  }

  Future<List<ReviewModel>> getTherapistReviews(int therapistId) async {
    final response = await apiClient.get(
      '/Reviews/therapist/$therapistId',
      requiresAuth: false,
    );

    return _parseReviews(response);
  }

  Future<void> createReview(CreateReviewRequest request) async {
    await apiClient.post('/Reviews', body: request.toJson());
  }

  Future<List<ReviewModel>> getMyReviews() async {
    final response = await apiClient.get('/Reviews/mine');

    return _parseReviews(response);
  }

  List<ReviewModel> _parseReviews(dynamic response) {
    final dynamic items;

    if (response is List) {
      items = response;
    } else if (response is Map<String, dynamic>) {
      items = response['items'];
    } else {
      return [];
    }

    if (items is! List) {
      return [];
    }

    return items
        .whereType<Map>()
        .map((item) => ReviewModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
