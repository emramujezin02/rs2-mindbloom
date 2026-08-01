import '../models/admin_review_details_model.dart';
import '../models/admin_reviews_paged_response.dart';
import '../services/review_moderation_api_service.dart';

class ReviewModerationRepository {
  final ReviewModerationApiService apiService;

  ReviewModerationRepository({required this.apiService});

  Future<AdminReviewsPagedResponse> getReviews({
    required int pageNumber,
    required int pageSize,
    String? search,
    int? rating,
    int? therapistId,
    int? status,
    bool? hasTherapistReply,
  }) {
    return apiService.getReviews(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
      rating: rating,
      therapistId: therapistId,
      status: status,
      hasTherapistReply: hasTherapistReply,
    );
  }

  Future<AdminReviewDetailsModel> getDetails(int reviewId) {
    return apiService.getDetails(reviewId);
  }

  Future<void> approveReview(int reviewId) {
    return apiService.approveReview(reviewId);
  }

  Future<void> rejectReview({required int reviewId, required String reason}) {
    return apiService.rejectReview(reviewId: reviewId, reason: reason);
  }

  Future<void> hideReview({required int reviewId, required String reason}) {
    return apiService.hideReview(reviewId: reviewId, reason: reason);
  }

  Future<void> deleteReview({required int reviewId, required String reason}) {
    return apiService.deleteReview(reviewId: reviewId, reason: reason);
  }
}
