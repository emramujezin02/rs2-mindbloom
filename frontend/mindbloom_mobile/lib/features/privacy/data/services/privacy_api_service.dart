import '../../../../core/network/api_client.dart';
import '../models/privacy_current_versions_model.dart';
import '../models/user_consent_model.dart';

class PrivacyApiService {
  final ApiClient apiClient;

  PrivacyApiService({required this.apiClient});

  Future<List<UserConsentModel>> getMyConsents() async {
    final response = await apiClient.get('/privacy/my-consents');

    if (response is! List) {
      throw Exception('The server returned invalid consent data.');
    }

    return response
        .whereType<Map>()
        .map(
          (item) => UserConsentModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<PrivacyCurrentVersionsModel> getCurrentVersions() async {
    final response = await apiClient.get(
      '/privacy/current-versions',
      requiresAuth: false,
    );

    if (response is! Map) {
      throw Exception('The server returned invalid privacy configuration.');
    }

    return PrivacyCurrentVersionsModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }
}
