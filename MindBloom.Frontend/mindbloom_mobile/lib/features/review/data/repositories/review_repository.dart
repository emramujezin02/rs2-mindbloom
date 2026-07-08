import '../models/review_model.dart';
import '../services/review_api_service.dart';

class ReviewRepository {
  final ReviewApiService apiService;

  ReviewRepository({required this.apiService});

  Future<List<ReviewModel>> getTherapistReviews(int therapistId) {
    return apiService.getTherapistReviews(therapistId);
  }
}
