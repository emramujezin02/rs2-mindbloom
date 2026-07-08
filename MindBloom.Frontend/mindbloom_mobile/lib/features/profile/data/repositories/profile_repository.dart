import '../models/profile_model.dart';
import '../services/profile_api_service.dart';

class ProfileRepository {
  final ProfileApiService apiService;

  ProfileRepository({required this.apiService});

  Future<ProfileModel> getProfile() {
    return apiService.getProfile();
  }
}
