import '../models/create_review_request.dart';
import '../models/review_eligibility_model.dart';
import '../models/review_model.dart';
import '../models/review_page_result.dart';
import '../models/therapist_rating_model.dart';
import '../models/update_review_request.dart';
import '../services/review_api_service.dart';

class ReviewRepository {
  final ReviewApiService apiService;

  ReviewRepository({required this.apiService});

  Future<List<ReviewModel>> getPublicReviews({int limit = 6}) {
    return apiService.getPublicReviews(limit: limit);
  }

  Future<ReviewPageResult> getTherapistReviews({
    required int therapistId,
    required int pageNumber,
    required int pageSize,
  }) {
    return apiService.getTherapistReviews(
      therapistId: therapistId,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
  }

  Future<TherapistRatingModel> getTherapistRating(int therapistId) {
    return apiService.getTherapistRating(therapistId);
  }

  Future<ReviewEligibilityModel> getEligibility(int appointmentId) {
    return apiService.getEligibility(appointmentId);
  }

  Future<void> createReview(CreateReviewRequest request) {
    return apiService.createReview(request);
  }

  Future<void> updateReview({
    required int reviewId,
    required UpdateReviewRequest request,
  }) {
    return apiService.updateReview(reviewId: reviewId, request: request);
  }

  Future<ReviewPageResult> getMyReviews({
    required int pageNumber,
    required int pageSize,
  }) {
    return apiService.getMyReviews(pageNumber: pageNumber, pageSize: pageSize);
  }
}
