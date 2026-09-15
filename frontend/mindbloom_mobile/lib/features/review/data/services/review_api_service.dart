import '../../../../core/network/api_client.dart';
import '../models/create_review_request.dart';
import '../models/review_eligibility_model.dart';
import '../models/review_model.dart';
import '../models/review_page_result.dart';
import '../models/therapist_rating_model.dart';
import '../models/update_review_request.dart';

class ReviewApiService {
  final ApiClient apiClient;

  ReviewApiService({required this.apiClient});

  Future<List<ReviewModel>> getPublicReviews({int limit = 6}) async {
    final response = await apiClient.get(
      '/Reviews/public?limit=$limit',
      requiresAuth: false,
    );

    return _parseReviewList(response);
  }

  Future<ReviewPageResult> getTherapistReviews({
    required int therapistId,
    required int pageNumber,
    required int pageSize,
  }) async {
    final response = await apiClient.get(
      '/Reviews/therapist/$therapistId'
      '?pageNumber=$pageNumber'
      '&pageSize=$pageSize',
      requiresAuth: false,
    );

    if (response is! Map<String, dynamic>) {
      return ReviewPageResult(
        items: const [],
        pageNumber: pageNumber,
        pageSize: pageSize,
        totalCount: 0,
      );
    }

    return ReviewPageResult.fromJson(
      response,
      requestedPage: pageNumber,
      requestedPageSize: pageSize,
    );
  }

  Future<TherapistRatingModel> getTherapistRating(int therapistId) async {
    final response = await apiClient.get(
      '/Reviews/therapist/$therapistId/rating',
      requiresAuth: false,
    );

    if (response is! Map<String, dynamic>) {
      return TherapistRatingModel(
        therapistId: therapistId,
        averageRating: 0,
        totalReviews: 0,
      );
    }

    return TherapistRatingModel.fromJson(response);
  }

  Future<ReviewEligibilityModel> getEligibility(int appointmentId) async {
    final response = await apiClient.get('/Reviews/eligibility/$appointmentId');

    if (response is! Map<String, dynamic>) {
      return ReviewEligibilityModel(
        appointmentId: appointmentId,
        canReview: false,
        message: 'Review eligibility could not be determined.',
      );
    }

    return ReviewEligibilityModel.fromJson(response);
  }

  Future<void> createReview(CreateReviewRequest request) async {
    await apiClient.post('/Reviews', body: request.toJson());
  }

  Future<void> updateReview({
    required int reviewId,
    required UpdateReviewRequest request,
  }) async {
    await apiClient.put('/Reviews/$reviewId', body: request.toJson());
  }

  Future<ReviewPageResult> getMyReviews({
    required int pageNumber,
    required int pageSize,
  }) async {
    final response = await apiClient.get(
      '/Reviews/mine'
      '?pageNumber=$pageNumber'
      '&pageSize=$pageSize',
    );

    if (response is! Map<String, dynamic>) {
      return ReviewPageResult(
        items: const [],
        pageNumber: pageNumber,
        pageSize: pageSize,
        totalCount: 0,
      );
    }

    return ReviewPageResult.fromJson(
      response,
      requestedPage: pageNumber,
      requestedPageSize: pageSize,
    );
  }

  List<ReviewModel> _parseReviewList(dynamic response) {
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
