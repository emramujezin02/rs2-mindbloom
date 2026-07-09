import '../../../../core/network/api_client.dart';
import '../models/therapist_model.dart';
import '../models/therapist_filter_request.dart';

class TherapistApiService {
  final ApiClient apiClient;

  TherapistApiService({required this.apiClient});

  Future<List<TherapistModel>> getTherapists() async {
    final response = await apiClient.get('/Therapists');

    return (response as List).map((x) => TherapistModel.fromJson(x)).toList();
  }

  Future<List<TherapistModel>> searchTherapists(
    TherapistFilterRequest request,
  ) async {
    final uri = Uri(
      path: '/Therapists/search',
      queryParameters: request.toQueryParameters(),
    );

    final response = await apiClient.get(uri.toString());

    final items = response['items'] ?? response;

    return (items as List).map((x) => TherapistModel.fromJson(x)).toList();
  }
}
