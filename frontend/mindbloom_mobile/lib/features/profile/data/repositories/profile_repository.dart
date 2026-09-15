import '../models/profile_model.dart';
import '../models/update_profile_request.dart';
import '../services/profile_api_service.dart';

class ProfileRepository {
  final ProfileApiService apiService;

  ProfileRepository({required this.apiService});

  Future<ProfileModel> getProfile() {
    return apiService.getProfile();
  }

  Future<ProfileModel> updateProfile(UpdateProfileRequest request) {
    return apiService.updateProfile(request);
  }

  Future<ProfileModel> uploadProfileImage(String filePath) {
    return apiService.uploadProfileImage(filePath);
  }
}
