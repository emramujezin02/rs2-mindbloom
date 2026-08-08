import '../models/privacy_current_versions_model.dart';
import '../models/user_consent_model.dart';
import '../services/privacy_api_service.dart';

class PrivacyRepository {
  final PrivacyApiService apiService;

  PrivacyRepository({required this.apiService});

  Future<List<UserConsentModel>> getMyConsents() {
    return apiService.getMyConsents();
  }

  Future<PrivacyCurrentVersionsModel> getCurrentVersions() {
    return apiService.getCurrentVersions();
  }
}
