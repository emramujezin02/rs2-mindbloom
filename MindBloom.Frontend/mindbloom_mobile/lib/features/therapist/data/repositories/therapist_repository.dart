import '../models/therapist_model.dart';
import '../services/therapist_api_service.dart';
import '../models/therapist_filter_request.dart';

class TherapistRepository {
  final TherapistApiService therapistApiService;

  TherapistRepository({required this.therapistApiService});

  Future<List<TherapistModel>> getTherapists() {
    return therapistApiService.getTherapists();
  }

  Future<List<TherapistModel>> searchTherapists(
    TherapistFilterRequest request,
  ) {
    return therapistApiService.searchTherapists(request);
  }
}
