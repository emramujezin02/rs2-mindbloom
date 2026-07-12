import '../../../../core/network/api_client.dart';
import '../models/therapist_details_model.dart';
import '../models/therapist_filter_request.dart';
import '../models/therapist_model.dart';

class TherapistApiService {
  final ApiClient apiClient;

  TherapistApiService({required this.apiClient});

  Future<List<TherapistModel>> getTherapists() async {
    final response = await apiClient.get('/Therapists');

    return (response as List)
        .map((item) => TherapistModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TherapistModel>> searchTherapists(
    TherapistFilterRequest request,
  ) async {
    final uri = Uri(
      path: '/Therapists/search',
      queryParameters: request.toQueryParameters(),
    );

    final response = await apiClient.get(uri.toString());

    final items = response is Map<String, dynamic>
        ? response['items']
        : response;

    return (items as List)
        .map((item) => TherapistModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TherapistDetailsModel> getTherapistById(int therapistId) async {
    final response = await apiClient.get('/Therapists/$therapistId');

    return TherapistDetailsModel.fromJson(response as Map<String, dynamic>);
  }
}
