import '../../../../core/network/api_client.dart';
import '../models/therapist_verification_details_model.dart';
import '../models/therapist_verification_paged_response.dart';

class TherapistVerificationApiService {
  final ApiClient apiClient;

  TherapistVerificationApiService({required this.apiClient});

  Future<TherapistVerificationPagedResponse> getPendingTherapists({
    required int pageNumber,
    required int pageSize,
    String? search,
  }) async {
    final parameters = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
    };

    if (search != null && search.trim().isNotEmpty) {
      parameters['search'] = search.trim();
    }

    final uri = Uri(
      path: '/Admin/therapists/pending',
      queryParameters: parameters,
    );

    final response = await apiClient.get(uri.toString());

    if (response is! Map<String, dynamic>) {
      throw Exception('Invalid therapist verification response.');
    }

    return TherapistVerificationPagedResponse.fromJson(response);
  }

  Future<TherapistVerificationDetailsModel> getDetails(int therapistId) async {
    final response = await apiClient.get(
      '/Admin/therapists/$therapistId/verification',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Invalid therapist details response.');
    }

    return TherapistVerificationDetailsModel.fromJson(response);
  }

  Future<void> updateVerification({
    required int therapistId,
    required int status,
    String? notes,
  }) async {
    await apiClient.put(
      '/Admin/therapists/$therapistId/verification',
      body: {'status': status, 'notes': notes},
    );
  }
}
