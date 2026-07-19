import '../../../../core/network/api_client.dart';
import '../models/therapist_details_model.dart';
import '../models/therapist_filter_request.dart';
import '../models/therapist_model.dart';
import '../models/therapist_dashboard_model.dart';
import '../models/therapist_client_details_model.dart';
import '../models/therapist_client_model.dart';

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

  Future<TherapistDashboardModel> getDashboard() async {
    final response = await apiClient.get('/Therapists/dashboard');

    return TherapistDashboardModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<TherapistClientModel>>
getTherapistClients({
  String? search,
}) async {
  final normalizedSearch =
      search?.trim() ?? '';

  final path =
      normalizedSearch.isEmpty
          ? '/Therapists/clients'
          : '/Therapists/clients'
              '?search=${Uri.encodeQueryComponent(normalizedSearch)}';

  final response = await apiClient.get(path);

  if (response == null) {
    return [];
  }

  final dynamic items;

  if (response is Map<String, dynamic>) {
    items =
        response['items'] ??
        response['data'] ??
        [];
  } else {
    items = response;
  }

  if (items is! List) {
    return [];
  }

  return items
      .whereType<Map>()
      .map(
        (item) =>
            TherapistClientModel.fromJson(
              Map<String, dynamic>.from(
                item,
              ),
            ),
      )
      .toList();
}

Future<TherapistClientDetailsModel>
getTherapistClientDetails(
  int clientId,
) async {
  final response = await apiClient.get(
    '/Therapists/clients/$clientId',
  );

  if (response is! Map) {
    throw Exception(
      'Invalid client details response.',
    );
  }

  return TherapistClientDetailsModel.fromJson(
    Map<String, dynamic>.from(response),
  );
}
}
