import '../models/therapist_specialization_model.dart';
import '../models/therapist_specialization_paged_response.dart';
import '../services/reference_data_api_service.dart';

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
}
