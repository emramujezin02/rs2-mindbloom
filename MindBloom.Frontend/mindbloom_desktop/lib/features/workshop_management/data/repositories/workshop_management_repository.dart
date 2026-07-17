import '../models/therapist_option_model.dart';
import '../models/workshop_model.dart';
import '../models/workshop_paged_response.dart';
import '../models/workshop_registration_paged_response.dart';
import '../services/workshop_management_api_service.dart';

class WorkshopManagementRepository {
  final WorkshopManagementApiService apiService;

  WorkshopManagementRepository({required this.apiService});

  Future<WorkshopPagedResponse> getWorkshops({
    String? search,
    int? type,
    int? status,
    DateTime? fromUtc,
    DateTime? toUtc,
    int pageNumber = 1,
    int pageSize = 10,
  }) {
    return apiService.getWorkshops(
      search: search,
      type: type,
      status: status,
      fromUtc: fromUtc,
      toUtc: toUtc,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
  }

  Future<WorkshopModel> getWorkshop(int workshopId) {
    return apiService.getWorkshop(workshopId);
  }

  Future<WorkshopRegistrationPagedResponse> getRegistrations({
    required int workshopId,
    int pageNumber = 1,
    int pageSize = 10,
  }) {
    return apiService.getRegistrations(
      workshopId: workshopId,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
  }

  Future<List<TherapistOptionModel>> getTherapists() {
    return apiService.getTherapists();
  }

  Future<WorkshopModel> createWorkshop({
    required String title,
    required String description,
    required DateTime startUtc,
    required DateTime endUtc,
    required int type,
    required String? onlineLink,
    required String? location,
    required int capacity,
    required double price,
    required int? therapistId,
  }) {
    return apiService.createWorkshop(
      title: title,
      description: description,
      startUtc: startUtc,
      endUtc: endUtc,
      type: type,
      onlineLink: onlineLink,
      location: location,
      capacity: capacity,
      price: price,
      therapistId: therapistId,
    );
  }

  Future<WorkshopModel> updateWorkshop({
    required int workshopId,
    required String title,
    required String description,
    required DateTime startUtc,
    required DateTime endUtc,
    required int type,
    required String? onlineLink,
    required String? location,
    required int capacity,
    required double price,
    required int? therapistId,
  }) {
    return apiService.updateWorkshop(
      workshopId: workshopId,
      title: title,
      description: description,
      startUtc: startUtc,
      endUtc: endUtc,
      type: type,
      onlineLink: onlineLink,
      location: location,
      capacity: capacity,
      price: price,
      therapistId: therapistId,
    );
  }

  Future<WorkshopModel> cancelWorkshop({
    required int workshopId,
    required String reason,
  }) {
    return apiService.cancelWorkshop(workshopId: workshopId, reason: reason);
  }

  Future<void> deleteWorkshop(int workshopId) {
    return apiService.deleteWorkshop(workshopId);
  }
}
