import '../../../../core/network/api_client.dart';
import '../models/therapist_model.dart';

class TherapistApiService {
  final ApiClient apiClient;

  TherapistApiService({required this.apiClient});

  Future<List<TherapistModel>> getTherapists() async {
    final response = await apiClient.get('/Therapists');

    return (response as List).map((x) => TherapistModel.fromJson(x)).toList();
  }
}
