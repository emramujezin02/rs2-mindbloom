import '../../../../core/network/api_client.dart';
import '../models/therapist_specialization_model.dart';
import '../models/therapist_specialization_paged_response.dart';
import '../models/therapy_approach_model.dart';
import '../models/therapy_approach_paged_response.dart';
import '../models/article_category_reference_model.dart';
import '../models/article_category_reference_paged_response.dart';

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

  Future<TherapyApproachPagedResponse> getTherapyApproaches({
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
      '/reference-data/therapy-approaches?$queryString',
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid therapy approaches response.');
    }

    return TherapyApproachPagedResponse.fromJson(response);
  }

  Future<TherapyApproachModel> createTherapyApproach({
    required String name,
    String? description,
    required bool isActive,
  }) async {
    final response = await apiClient.post(
      '/reference-data/therapy-approaches',
      body: {
        'name': name.trim(),
        'description': _normalizeOptionalText(description),
        'isActive': isActive,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid therapy approach response.');
    }

    return TherapyApproachModel.fromJson(response);
  }

  Future<TherapyApproachModel> updateTherapyApproach({
    required int id,
    required String name,
    String? description,
  }) async {
    final response = await apiClient.put(
      '/reference-data/therapy-approaches/$id',
      body: {
        'name': name.trim(),
        'description': _normalizeOptionalText(description),
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid therapy approach response.');
    }

    return TherapyApproachModel.fromJson(response);
  }

  Future<TherapyApproachModel> updateTherapyApproachStatus({
    required int id,
    required bool isActive,
  }) async {
    final response = await apiClient.put(
      '/reference-data/therapy-approaches/$id/status',
      body: {'isActive': isActive},
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid therapy approach response.');
    }

    return TherapyApproachModel.fromJson(response);
  }

  Future<void> deleteTherapyApproach(int id) async {
    await apiClient.delete('/reference-data/therapy-approaches/$id');
  }

  Future<ArticleCategoryReferencePagedResponse> getArticleCategories({
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
      '/reference-data/article-categories?$queryString',
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid article categories response.');
    }

    return ArticleCategoryReferencePagedResponse.fromJson(response);
  }

  Future<ArticleCategoryReferenceModel> createArticleCategory({
    required String name,
    String? description,
    required bool isActive,
  }) async {
    final response = await apiClient.post(
      '/reference-data/article-categories',
      body: {
        'name': name.trim(),
        'description': _normalizeOptionalText(description),
        'isActive': isActive,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid article category response.');
    }

    return ArticleCategoryReferenceModel.fromJson(response);
  }

  Future<ArticleCategoryReferenceModel> updateArticleCategory({
    required int id,
    required String name,
    String? description,
  }) async {
    final response = await apiClient.put(
      '/reference-data/article-categories/$id',
      body: {
        'name': name.trim(),
        'description': _normalizeOptionalText(description),
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid article category response.');
    }

    return ArticleCategoryReferenceModel.fromJson(response);
  }

  Future<ArticleCategoryReferenceModel> updateArticleCategoryStatus({
    required int id,
    required bool isActive,
  }) async {
    final response = await apiClient.put(
      '/reference-data/article-categories/$id/status',
      body: {'isActive': isActive},
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid article category response.');
    }

    return ArticleCategoryReferenceModel.fromJson(response);
  }

  Future<void> deleteArticleCategory(int id) async {
    await apiClient.delete('/reference-data/article-categories/$id');
  }

  Future<List<TherapistSpecializationModel>>
  getActiveTherapistSpecializations() async {
    final response = await apiClient.get(
      '/reference-data/therapist-specializations/active',
    );

    if (response is! List) {
      throw const FormatException(
        'Invalid active therapist specializations response.',
      );
    }

    return response
        .map(
          (item) => TherapistSpecializationModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .where(
          (item) => item.id > 0 && item.name.trim().isNotEmpty && item.isActive,
        )
        .toList();
  }

  Future<List<TherapyApproachModel>> getActiveTherapyApproaches() async {
    final response = await apiClient.get(
      '/reference-data/therapy-approaches/active',
    );

    if (response is! List) {
      throw const FormatException(
        'Invalid active therapy approaches response.',
      );
    }

    return response
        .map(
          (item) => TherapyApproachModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .where(
          (item) => item.id > 0 && item.name.trim().isNotEmpty && item.isActive,
        )
        .toList();
  }

  Future<List<ArticleCategoryReferenceModel>>
  getActiveArticleCategories() async {
    final response = await apiClient.get(
      '/reference-data/article-categories/active',
    );

    if (response is! List) {
      throw const FormatException(
        'Invalid active article categories response.',
      );
    }

    return response
        .map(
          (item) => ArticleCategoryReferenceModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .where(
          (item) => item.id > 0 && item.name.trim().isNotEmpty && item.isActive,
        )
        .toList();
  }
}
