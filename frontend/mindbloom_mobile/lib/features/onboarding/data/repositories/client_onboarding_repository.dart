import '../models/client_onboarding_model.dart';
import '../models/save_client_onboarding_request.dart';
import '../services/client_onboarding_api_service.dart';

class ClientOnboardingRepository {
  final ClientOnboardingApiService apiService;

  ClientOnboardingRepository({required this.apiService});

  Future<ClientOnboardingModel> getOnboarding() {
    return apiService.getOnboarding();
  }

  Future<ClientOnboardingModel> saveOnboarding(
    SaveClientOnboardingRequest request,
  ) {
    return apiService.saveOnboarding(request);
  }
}
