import '../models/therapist_specialization_model.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/create_unavailable_date_request.dart';

import '../../../../core/models/paged_response.dart';
import '../../../../core/network/api_client.dart';
import '../models/therapist_document_model.dart';
import '../models/therapist_location_model.dart';
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
import '../models/therapist_mood_entry_model.dart';
import '../models/therapist_mood_trend_model.dart';
import '../models/therapist_search_page_model.dart';
import '../../../appointment/data/models/unavailable_date_model.dart';
import '../models/therapist_availability_model.dart';

class TherapistApiService {
  Future<PagedResponse<TherapistLocationModel>> getActiveLocations({
    int pageNumber = 1,
  }) async {
    final response = await apiClient.get(
      '/reference-data/locations/active?pageNumber=$pageNumber&pageSize=50',
      requiresAuth: false,
    );
    return PagedResponse<TherapistLocationModel>.fromJson(
      Map<String, dynamic>.from(response as Map),
      TherapistLocationModel.fromJson,
    );
  }

  Future<List<TherapistSpecializationModel>> getActiveSpecializations() async =>
      (await getFilterOptions(
        'therapist-specializations',
      )).map(TherapistSpecializationModel.fromJson).toList();

  Future<List<Map<String, dynamic>>> getFilterOptions(String kind) async {
    final response = await apiClient.get(
      '/reference-data/$kind/active',
      requiresAuth: false,
    );
    return (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<PagedResponse<TherapistDocumentModel>> getMyDocuments({
    int pageNumber = 1,
  }) async {
    final json = await apiClient.get(
      '/Therapists/documents/me?pageNumber=$pageNumber&pageSize=10',
    );
    return PagedResponse<TherapistDocumentModel>.fromJson(
      Map<String, dynamic>.from(json as Map),
      TherapistDocumentModel.fromJson,
    );
  }

  Future<void> uploadVerificationDocument(
    String path,
    String contentType,
  ) async {
    await apiClient.multipartPost(
      '/Therapists/documents',
      filePath: path,
      fileFieldName: 'File',
      contentType: contentType,
    );
  }

  final ApiClient apiClient;

  TherapistApiService({required this.apiClient});

  Future<PagedResponse<TherapistModel>> getTherapists({
    int page = 1,
    int pageSize = 10,
  }) async {
    final uri = Uri(
      path: '/Therapists',
      queryParameters: {'Page': '$page', 'PageSize': '$pageSize'},
    );
    final response = await apiClient.get(uri.toString());
    if (response is! Map) {
      throw const FormatException(
        'The server returned an invalid therapist page.',
      );
    }
    return PagedResponse<TherapistModel>.fromJson(
      Map<String, dynamic>.from(response),
      TherapistModel.fromJson,
    );
  }

  Future<TherapistSearchPageModel> searchTherapists(
    TherapistFilterRequest request,
  ) async {
    final uri = Uri(
      path: '/Therapists/search',
      queryParameters: request.toQueryParameters(),
    );

    final response = await apiClient.get(uri.toString());

    if (response is! Map) {
      throw const FormatException(
        'The server returned an invalid '
        'therapist search response.',
      );
    }

    return TherapistSearchPageModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<TherapistDetailsModel> getTherapistById(int therapistId) async {
    final response = await apiClient.get('/Therapists/$therapistId');

    return TherapistDetailsModel.fromJson(response as Map<String, dynamic>);
  }

  Future<TherapistDashboardModel> getDashboard() async {
    final response = await apiClient.get('/Therapists/dashboard');

    return TherapistDashboardModel.fromJson(response as Map<String, dynamic>);
  }

  Future<PagedResponse<TherapistClientModel>> getTherapistClients({
    String? search,
    required int pageNumber,
    required int pageSize,
  }) async {
    final normalizedSearch = search?.trim() ?? '';

    final query = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
      if (normalizedSearch.isNotEmpty) 'search': normalizedSearch,
    };

    final response = await apiClient.get(
      Uri(path: '/Therapists/clients', queryParameters: query).toString(),
    );

    return PagedResponse.fromJson(
      response as Map<String, dynamic>,
      TherapistClientModel.fromJson,
    );
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

  Future<void> deleteTherapistProfileImage() async {
    await apiClient.delete('/Therapists/profile/image');
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

  Future<void> deleteTherapistAvailability(int availabilityId) async {
    await apiClient.delete('/Therapists/availability/$availabilityId');
  }

  Future<List<TherapistMoodEntryModel>> getClientMoodHistory(
    int clientId,
  ) async {
    final response = await apiClient.get(
      '/JournalEntries/clients/$clientId/history',
    );

    final items = response['items'] as List? ?? [];

    return items
        .whereType<Map>()
        .map(
          (e) => TherapistMoodEntryModel.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<TherapistMoodTrendModel> getClientEmotionalAnalytics({
    required int clientId,
    required int days,
  }) async {
    final normalizedDays = _normalizeAnalyticsPeriod(days);

    final response = await apiClient.get(
      '/JournalEntries/clients/'
      '$clientId/analytics'
      '?days=$normalizedDays',
    );

    if (response is! Map) {
      throw const FormatException(
        'The server returned an invalid '
        'emotional analytics response.',
      );
    }

    return TherapistMoodTrendModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  int _normalizeAnalyticsPeriod(int days) {
    const allowedPeriods = {7, 14, 30, 90, 180, 365};

    if (allowedPeriods.contains(days)) {
      return days;
    }

    return 30;
  }

  Future<TherapistMoodTrendModel> getClientMoodTrend(int clientId) async {
    final response = await apiClient.get(
      '/JournalEntries/clients/'
      '$clientId/trend',
    );

    if (response is! Map) {
      throw const FormatException(
        'The server returned an invalid '
        'mood trend response.',
      );
    }

    return TherapistMoodTrendModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<List<TherapistAvailabilityModel>> getOwnAvailabilities(
    int therapistId,
  ) async {
    final response = await apiClient.get(
      '/Therapists/$therapistId/availability',
    );

    if (response is! List) {
      return [];
    }

    return response
        .whereType<Map>()
        .map(
          (item) => TherapistAvailabilityModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> addTherapistAvailability({
    required CreateTherapistAvailabilityRequest request,
  }) async {
    await apiClient.post('/Therapists/availability', body: request.toJson());
  }

  Future<PagedResponse<UnavailableDateModel>> getUnavailableDates({
    required int therapistId,
    required DateTime fromUtc,
    required DateTime toUtc,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final response = await apiClient.get(
      Uri(
        path: '/Therapists/$therapistId/unavailable-dates',
        queryParameters: {
          'pageNumber': pageNumber.toString(),
          'pageSize': pageSize.toString(),
          'fromUtc': fromUtc.toUtc().toIso8601String(),
          'toUtc': toUtc.toUtc().toIso8601String(),
        },
      ).toString(),
    );

    return PagedResponse.fromJson(
      response as Map<String, dynamic>,
      UnavailableDateModel.fromJson,
    );
  }

  Future<void> addUnavailableDate(CreateUnavailableDateRequest request) async {
    await apiClient.post(
      '/Therapists/unavailable-dates',
      body: request.toJson(),
    );
  }

  Future<void> deleteUnavailableDate(int unavailableDateId) async {
    await apiClient.delete('/Therapists/unavailable-dates/$unavailableDateId');
  }
}
