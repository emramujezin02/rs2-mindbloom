import '../models/review_model.dart';
import '../services/review_api_service.dart';
import '../models/create_review_request.dart';

class ReviewRepository {
  final ReviewApiService apiService;

  ReviewRepository({required this.apiService});

  Future<List<ReviewModel>> getTherapistReviews(int therapistId) {
    return apiService.getTherapistReviews(therapistId);
  }

  Future<void> createReview(CreateReviewRequest request) {
    return apiService.createReview(request);
  }
}
