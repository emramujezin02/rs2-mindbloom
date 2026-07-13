import '../../../../core/network/api_client.dart';
import '../models/workshop_model.dart';
import '../models/workshop_paged_response.dart';

class WorkshopApiService {
  final ApiClient apiClient;

  WorkshopApiService({required this.apiClient});

  Future<WorkshopPagedResponse> getWorkshops({
    required int pageNumber,
    required int pageSize,
    String? search,
  }) async {
    final queryParameters = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
    };

    final normalizedSearch = search?.trim() ?? '';

    if (normalizedSearch.isNotEmpty) {
      queryParameters['search'] = normalizedSearch;
    }

    final uri = Uri(path: '/Workshops', queryParameters: queryParameters);

    final response = await apiClient.get(uri.toString());

    return WorkshopPagedResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<WorkshopModel> getWorkshop(int workshopId) async {
    final response = await apiClient.get('/Workshops/$workshopId');

    return WorkshopModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> register(int workshopId) async {
    await apiClient.post('/Workshops/$workshopId/register');
  }

  Future<void> cancelRegistration(int workshopId) async {
    await apiClient.delete('/Workshops/$workshopId/registration');
  }

  Future<WorkshopPagedResponse> getMyRegistrations({
    required int pageNumber,
    required int pageSize,
  }) async {
    final response = await apiClient.get(
      '/Workshops/mine'
      '?pageNumber=$pageNumber'
      '&pageSize=$pageSize',
    );

    return WorkshopPagedResponse.fromJson(response as Map<String, dynamic>);
  }
}
