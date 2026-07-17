import '../../../../core/network/api_client.dart';
import '../models/therapist_specialization_model.dart';
import '../models/therapist_specialization_paged_response.dart';

class ReferenceDataApiService {
  final ApiClient apiClient;

  const ReferenceDataApiService({required this.apiClient});

  Future<TherapistSpecializationPagedResponse> getTherapistSpecializations({
    required int pageNumber,
    required int pageSize,
    String? search,
    bool? isActive,
  }) async {
    final queryParameters = <String, String>{
      'PageNumber': pageNumber.toString(),
      'PageSize': pageSize.toString(),
    };

    final normalizedSearch = search?.trim();

    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      queryParameters['Search'] = normalizedSearch;
    }

    if (isActive != null) {
      queryParameters['IsActive'] = isActive.toString();
    }

    final queryString = Uri(queryParameters: queryParameters).query;

    final response = await apiClient.get(
      '/reference-data/therapist-specializations?$queryString',
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid therapist specializations response.',
      );
    }

    return TherapistSpecializationPagedResponse.fromJson(response);
  }

  Future<TherapistSpecializationModel> createTherapistSpecialization({
    required String name,
    String? description,
    required bool isActive,
  }) async {
    final response = await apiClient.post(
      '/reference-data/therapist-specializations',
      body: {
        'name': name.trim(),
        'description': _normalizeOptionalText(description),
        'isActive': isActive,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid therapist specialization response.');
    }

    return TherapistSpecializationModel.fromJson(response);
  }

  Future<TherapistSpecializationModel> updateTherapistSpecialization({
    required int id,
    required String name,
    String? description,
  }) async {
    final response = await apiClient.put(
      '/reference-data/therapist-specializations/$id',
      body: {
        'name': name.trim(),
        'description': _normalizeOptionalText(description),
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid therapist specialization response.');
    }

    return TherapistSpecializationModel.fromJson(response);
  }

  Future<TherapistSpecializationModel> updateTherapistSpecializationStatus({
    required int id,
    required bool isActive,
  }) async {
    final response = await apiClient.put(
      '/reference-data/therapist-specializations/$id/status',
      body: {'isActive': isActive},
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid therapist specialization response.');
    }

    return TherapistSpecializationModel.fromJson(response);
  }

  Future<void> deleteTherapistSpecialization(int id) async {
    await apiClient.delete('/reference-data/therapist-specializations/$id');
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();

    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
