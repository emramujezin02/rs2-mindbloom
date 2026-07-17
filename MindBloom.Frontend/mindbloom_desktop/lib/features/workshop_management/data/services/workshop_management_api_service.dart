import '../../../../core/network/api_client.dart';
import '../models/therapist_option_model.dart';
import '../models/workshop_model.dart';
import '../models/workshop_paged_response.dart';
import '../models/workshop_registration_paged_response.dart';

class WorkshopManagementApiService {
  final ApiClient apiClient;

  WorkshopManagementApiService({required this.apiClient});

  Future<WorkshopPagedResponse> getWorkshops({
    String? search,
    int? type,
    int? status,
    DateTime? fromUtc,
    DateTime? toUtc,
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final parameters = <String, String>{
      'PageNumber': pageNumber.toString(),
      'PageSize': pageSize.toString(),
    };

    if (search != null && search.trim().isNotEmpty) {
      parameters['Search'] = search.trim();
    }

    if (type != null) {
      parameters['Type'] = type.toString();
    }

    if (status != null) {
      parameters['Status'] = status.toString();
    }

    if (fromUtc != null) {
      parameters['FromUtc'] = fromUtc.toUtc().toIso8601String();
    }

    if (toUtc != null) {
      parameters['ToUtc'] = toUtc.toUtc().toIso8601String();
    }

    final query = Uri(queryParameters: parameters).query;

    final response = await apiClient.get('/Workshops/manage?$query');

    return WorkshopPagedResponse.fromJson(Map<String, dynamic>.from(response));
  }

  Future<WorkshopModel> getWorkshop(int workshopId) async {
    final response = await apiClient.get('/Workshops/$workshopId');

    return WorkshopModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<WorkshopRegistrationPagedResponse> getRegistrations({
    required int workshopId,
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final response = await apiClient.get(
      '/Workshops/$workshopId/registrations'
      '?pageNumber=$pageNumber'
      '&pageSize=$pageSize',
    );

    return WorkshopRegistrationPagedResponse.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<List<TherapistOptionModel>> getTherapists() async {
    final response = await apiClient.get('/Therapists');

    return (response as List)
        .map(
          (item) =>
              TherapistOptionModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
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
  }) async {
    final response = await apiClient.post(
      '/Workshops',
      body: {
        'title': title,
        'description': description,
        'startUtc': startUtc.toUtc().toIso8601String(),
        'endUtc': endUtc.toUtc().toIso8601String(),
        'type': type,
        'onlineLink': onlineLink,
        'location': location,
        'capacity': capacity,
        'price': price,
        'therapistId': therapistId,
      },
    );

    return WorkshopModel.fromJson(Map<String, dynamic>.from(response));
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
  }) async {
    final response = await apiClient.put(
      '/Workshops/$workshopId',
      body: {
        'title': title,
        'description': description,
        'startUtc': startUtc.toUtc().toIso8601String(),
        'endUtc': endUtc.toUtc().toIso8601String(),
        'type': type,
        'onlineLink': onlineLink,
        'location': location,
        'capacity': capacity,
        'price': price,
        'therapistId': therapistId,
      },
    );

    return WorkshopModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<WorkshopModel> cancelWorkshop({
    required int workshopId,
    required String reason,
  }) async {
    final response = await apiClient.put(
      '/Workshops/$workshopId/status',
      body: {'status': 2, 'reason': reason},
    );

    return WorkshopModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> deleteWorkshop(int workshopId) async {
    await apiClient.delete('/Workshops/$workshopId');
  }
}
