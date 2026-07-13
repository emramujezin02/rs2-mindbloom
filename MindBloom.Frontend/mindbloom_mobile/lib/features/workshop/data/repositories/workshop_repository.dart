import '../models/workshop_model.dart';
import '../models/workshop_paged_response.dart';
import '../services/workshop_api_service.dart';

class WorkshopRepository {
  final WorkshopApiService apiService;

  WorkshopRepository({required this.apiService});

  Future<WorkshopPagedResponse> getWorkshops({
    required int pageNumber,
    required int pageSize,
    String? search,
  }) {
    return apiService.getWorkshops(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
    );
  }

  Future<WorkshopModel> getWorkshop(int workshopId) {
    return apiService.getWorkshop(workshopId);
  }

  Future<void> register(int workshopId) {
    return apiService.register(workshopId);
  }

  Future<void> cancelRegistration(int workshopId) {
    return apiService.cancelRegistration(workshopId);
  }

  Future<WorkshopPagedResponse> getMyRegistrations({
    required int pageNumber,
    required int pageSize,
  }) {
    return apiService.getMyRegistrations(
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
  }
}
