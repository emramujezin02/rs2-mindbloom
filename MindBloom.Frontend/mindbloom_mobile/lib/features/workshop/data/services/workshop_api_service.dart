import '../../../../core/network/api_client.dart';
import '../models/workshop_model.dart';

class WorkshopApiService {
  final ApiClient apiClient;

  WorkshopApiService({required this.apiClient});

  Future<List<WorkshopModel>> getWorkshops() async {
    final response = await apiClient.get('/Workshops');

    return (response as List).map((e) => WorkshopModel.fromJson(e)).toList();
  }

  Future<void> register(int workshopId) async {
    await apiClient.post('/Workshops/$workshopId/register');
  }
}
