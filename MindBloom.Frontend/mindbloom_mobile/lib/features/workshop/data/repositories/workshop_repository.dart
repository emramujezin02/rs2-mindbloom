import '../models/workshop_model.dart';
import '../models/workshop_paged_response.dart';
import '../services/workshop_api_service.dart';
import '../../../../core/network/idempotency_key_generator.dart';

class WorkshopRepository {
  final WorkshopApiService apiService;
  final Map<int, String> _workshopRegistrationKeys = <int, String>{};

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

  Future<void> register(int workshopId) async {
    final idempotencyKey = _workshopRegistrationKeys.putIfAbsent(
      workshopId,
      IdempotencyKeyGenerator.generate,
    );

    try {
      await apiService.register(workshopId, idempotencyKey: idempotencyKey);

      _workshopRegistrationKeys.remove(workshopId);
    } catch (_) {
      rethrow;
    }
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
