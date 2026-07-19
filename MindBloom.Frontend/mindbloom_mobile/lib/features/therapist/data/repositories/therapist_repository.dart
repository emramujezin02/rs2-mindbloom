import '../models/therapist_details_model.dart';
import '../models/therapist_filter_request.dart';
import '../models/therapist_model.dart';
import '../services/therapist_api_service.dart';
import '../models/therapist_dashboard_model.dart';
import '../models/therapist_client_details_model.dart';
import '../models/therapist_client_model.dart';

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

  Future<TherapistDetailsModel> getTherapistById(int therapistId) {
    return therapistApiService.getTherapistById(therapistId);
  }

  Future<TherapistDashboardModel> getDashboard() {
    return therapistApiService.getDashboard();
  }

  Future<List<TherapistClientModel>>
getTherapistClients({
  String? search,
}) {
  return therapistApiService
      .getTherapistClients(
        search: search,
      );
}

Future<TherapistClientDetailsModel>
getTherapistClientDetails(
  int clientId,
) {
  return therapistApiService
      .getTherapistClientDetails(
        clientId,
      );
}
}
