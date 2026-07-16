import '../../../../core/network/api_client.dart';
import '../models/admin_review_details_model.dart';
import '../models/admin_reviews_paged_response.dart';

class ReviewModerationApiService {
  final ApiClient apiClient;

  ReviewModerationApiService({required this.apiClient});

  Future<AdminReviewsPagedResponse> getReviews({
    required int pageNumber,
    required int pageSize,
    String? search,
    int? rating,
    bool? hasTherapistReply,
    bool? isDeleted,
  }) async {
    final parameters = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
    };

    final normalizedSearch = search?.trim() ?? '';

    if (normalizedSearch.isNotEmpty) {
      parameters['search'] = normalizedSearch;
    }

    if (rating != null) {
      parameters['rating'] = rating.toString();
    }

    if (hasTherapistReply != null) {
      parameters['hasTherapistReply'] = hasTherapistReply.toString();
    }

    if (isDeleted != null) {
      parameters['isDeleted'] = isDeleted.toString();
    }

    final uri = Uri(path: '/Admin/reviews', queryParameters: parameters);

    final response = await apiClient.get(uri.toString());

    if (response is! Map<String, dynamic>) {
      throw Exception('The server returned invalid review data.');
    }

    return AdminReviewsPagedResponse.fromJson(response);
  }

  Future<AdminReviewDetailsModel> getDetails(int reviewId) async {
    final response = await apiClient.get('/Admin/reviews/$reviewId');

    if (response is! Map<String, dynamic>) {
      throw Exception('The server returned invalid review details.');
    }

    return AdminReviewDetailsModel.fromJson(response);
  }

  Future<void> deleteReview({
    required int reviewId,
    required String reason,
  }) async {
    await apiClient.put(
      '/Admin/reviews/$reviewId/delete',
      body: {'reason': reason},
    );
  }
}
