import '../models/therapy_approach_model.dart';
import '../services/therapy_approach_api_service.dart';

class TherapyApproachRepository {
  final TherapyApproachApiService apiService;

  TherapyApproachRepository({required this.apiService});

  Future<List<TherapyApproachModel>> getPublicTherapyApproaches() {
    return apiService.getPublicTherapyApproaches();
  }
}
