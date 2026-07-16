import '../models/therapist_verification_details_model.dart';
import '../models/therapist_verification_paged_response.dart';
import '../services/therapist_verification_api_service.dart';

class TherapistVerificationRepository {
  final TherapistVerificationApiService apiService;

  TherapistVerificationRepository({required this.apiService});

  Future<TherapistVerificationPagedResponse> getPendingTherapists({
    required int pageNumber,
    required int pageSize,
    String? search,
  }) {
    return apiService.getPendingTherapists(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
    );
  }

  Future<TherapistVerificationDetailsModel> getDetails(int therapistId) {
    return apiService.getDetails(therapistId);
  }

  Future<void> updateVerification({
    required int therapistId,
    required int status,
    String? notes,
  }) {
    return apiService.updateVerification(
      therapistId: therapistId,
      status: status,
      notes: notes,
    );
  }
}
