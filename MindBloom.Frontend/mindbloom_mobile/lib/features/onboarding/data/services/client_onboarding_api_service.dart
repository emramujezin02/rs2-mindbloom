import '../../../../core/network/api_client.dart';
import '../models/client_onboarding_model.dart';
import '../models/save_client_onboarding_request.dart';

class ClientOnboardingApiService {
  final ApiClient apiClient;

  ClientOnboardingApiService({required this.apiClient});

  Future<ClientOnboardingModel> getOnboarding() async {
    final response = await apiClient.get('/client-onboarding');

    return ClientOnboardingModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<ClientOnboardingModel> saveOnboarding(
    SaveClientOnboardingRequest request,
  ) async {
    final response = await apiClient.put(
      '/client-onboarding',
      body: request.toJson(),
    );

    return ClientOnboardingModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
