import '../../../../core/network/api_client.dart';
import '../models/therapist_details_model.dart';
import '../models/therapist_filter_request.dart';
import '../models/therapist_model.dart';
import '../models/therapist_dashboard_model.dart';
import '../models/therapist_client_details_model.dart';
import '../models/therapist_client_model.dart';
import 'dart:io';
import '../models/create_therapist_availability_request.dart';
import '../models/therapist_profile_image_model.dart';
import '../models/therapist_profile_model.dart';
import '../models/update_therapist_profile_request.dart';

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

  Future<List<TherapistClientModel>> getTherapistClients({
    String? search,
  }) async {
    final normalizedSearch = search?.trim() ?? '';

    final path = normalizedSearch.isEmpty
        ? '/Therapists/clients'
        : '/Therapists/clients'
              '?search=${Uri.encodeQueryComponent(normalizedSearch)}';

    final response = await apiClient.get(path);

    if (response == null) {
      return [];
    }

    final dynamic items;

    if (response is Map<String, dynamic>) {
      items = response['items'] ?? response['data'] ?? [];
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
              TherapistClientModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<TherapistClientDetailsModel> getTherapistClientDetails(
    int clientId,
  ) async {
    final response = await apiClient.get('/Therapists/clients/$clientId');

    if (response is! Map) {
      throw Exception('Invalid client details response.');
    }

    return TherapistClientDetailsModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<TherapistProfileModel> getTherapistProfile() async {
    final response = await apiClient.get('/Therapists/profile');

    return TherapistProfileModel.fromJson(_asJsonMap(response));
  }

  Future<void> updateTherapistProfile(
    UpdateTherapistProfileRequest request,
  ) async {
    await apiClient.put('/Therapists/profile', body: request.toJson());
  }

  Future<TherapistProfileImageModel> uploadTherapistProfileImage(
    File file,
  ) async {
    final response = await apiClient.multipartPost(
      '/Therapists/profile/image',
      filePath: file.path,
      fileFieldName: 'file',
    );

    return TherapistProfileImageModel.fromJson(_asJsonMap(response));
  }

  Map<String, dynamic> _asJsonMap(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw const FormatException('The server returned an invalid response.');
  }

  Future<void> addTherapistAvailability({
    required int therapistId,
    required CreateTherapistAvailabilityRequest request,
  }) async {
    await apiClient.post(
      '/Therapists/$therapistId/availability',
      body: request.toJson(),
    );
  }

  Future<void> deleteTherapistAvailability(int availabilityId) async {
    await apiClient.delete('/Therapists/availability/$availabilityId');
  }
}
