import '../models/therapist_specialization_model.dart';
import '../models/therapist_specialization_paged_response.dart';
import '../services/reference_data_api_service.dart';
import '../models/therapy_approach_model.dart';
import '../models/therapy_approach_paged_response.dart';
import '../models/article_category_reference_model.dart';
import '../models/article_category_reference_paged_response.dart';

class ReferenceDataRepository {
  final ReferenceDataApiService apiService;

  const ReferenceDataRepository({required this.apiService});

  Future<TherapistSpecializationPagedResponse> getTherapistSpecializations({
    required int pageNumber,
    required int pageSize,
    String? search,
    bool? isActive,
  }) {
    return apiService.getTherapistSpecializations(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
      isActive: isActive,
    );
  }

  Future<TherapistSpecializationModel> createTherapistSpecialization({
    required String name,
    String? description,
    required bool isActive,
  }) {
    return apiService.createTherapistSpecialization(
      name: name,
      description: description,
      isActive: isActive,
    );
  }

  Future<TherapistSpecializationModel> updateTherapistSpecialization({
    required int id,
    required String name,
    String? description,
  }) {
    return apiService.updateTherapistSpecialization(
      id: id,
      name: name,
      description: description,
    );
  }

  Future<TherapistSpecializationModel> updateTherapistSpecializationStatus({
    required int id,
    required bool isActive,
  }) {
    return apiService.updateTherapistSpecializationStatus(
      id: id,
      isActive: isActive,
    );
  }

  Future<void> deleteTherapistSpecialization(int id) {
    return apiService.deleteTherapistSpecialization(id);
  }

  Future<TherapyApproachPagedResponse> getTherapyApproaches({
    required int pageNumber,
    required int pageSize,
    String? search,
    bool? isActive,
  }) {
    return apiService.getTherapyApproaches(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
      isActive: isActive,
    );
  }

  Future<TherapyApproachModel> createTherapyApproach({
    required String name,
    String? description,
    required bool isActive,
  }) {
    return apiService.createTherapyApproach(
      name: name,
      description: description,
      isActive: isActive,
    );
  }

  Future<TherapyApproachModel> updateTherapyApproach({
    required int id,
    required String name,
    String? description,
  }) {
    return apiService.updateTherapyApproach(
      id: id,
      name: name,
      description: description,
    );
  }

  Future<TherapyApproachModel> updateTherapyApproachStatus({
    required int id,
    required bool isActive,
  }) {
    return apiService.updateTherapyApproachStatus(id: id, isActive: isActive);
  }

  Future<void> deleteTherapyApproach(int id) {
    return apiService.deleteTherapyApproach(id);
  }

  Future<ArticleCategoryReferencePagedResponse> getArticleCategories({
    required int pageNumber,
    required int pageSize,
    String? search,
    bool? isActive,
  }) {
    return apiService.getArticleCategories(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
      isActive: isActive,
    );
  }

  Future<ArticleCategoryReferenceModel> createArticleCategory({
    required String name,
    String? description,
    required bool isActive,
  }) {
    return apiService.createArticleCategory(
      name: name,
      description: description,
      isActive: isActive,
    );
  }

  Future<ArticleCategoryReferenceModel> updateArticleCategory({
    required int id,
    required String name,
    String? description,
  }) {
    return apiService.updateArticleCategory(
      id: id,
      name: name,
      description: description,
    );
  }

  Future<ArticleCategoryReferenceModel> updateArticleCategoryStatus({
    required int id,
    required bool isActive,
  }) {
    return apiService.updateArticleCategoryStatus(id: id, isActive: isActive);
  }

  Future<void> deleteArticleCategory(int id) {
    return apiService.deleteArticleCategory(id);
  }

  Future<List<TherapistSpecializationModel>>
  getActiveTherapistSpecializations() {
    return apiService.getActiveTherapistSpecializations();
  }

  Future<List<TherapyApproachModel>> getActiveTherapyApproaches() {
    return apiService.getActiveTherapyApproaches();
  }

  Future<List<ArticleCategoryReferenceModel>> getActiveArticleCategories() {
    return apiService.getActiveArticleCategories();
  }
}
