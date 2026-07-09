import '../models/workshop_model.dart';
import '../services/workshop_api_service.dart';

class WorkshopRepository {
  final WorkshopApiService apiService;

  WorkshopRepository({required this.apiService});

  Future<List<WorkshopModel>> getWorkshops() {
    return apiService.getWorkshops();
  }

  Future<void> register(int workshopId) {
    return apiService.register(workshopId);
  }
}
