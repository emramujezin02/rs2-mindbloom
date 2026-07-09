import '../models/profile_model.dart';
import '../services/profile_api_service.dart';
import '../models/update_profile_request.dart';

class ProfileRepository {
  final ProfileApiService apiService;

  ProfileRepository({required this.apiService});

  Future<ProfileModel> getProfile() {
    return apiService.getProfile();
  }

  Future<void> updateProfile(UpdateProfileRequest request) {
    return apiService.updateProfile(request);
  }
}
