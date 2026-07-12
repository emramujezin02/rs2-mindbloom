import '../../../../core/network/api_client.dart';
import '../models/profile_model.dart';
import '../models/update_profile_request.dart';

class ProfileApiService {
  final ApiClient apiClient;

  ProfileApiService({required this.apiClient});

  Future<ProfileModel> getProfile() async {
    final response = await apiClient.get('/Users/me');

    return ProfileModel.fromJson(response as Map<String, dynamic>);
  }

  Future<ProfileModel> updateProfile(UpdateProfileRequest request) async {
    final response = await apiClient.put('/Users/me', body: request.toJson());

    return ProfileModel.fromJson(response as Map<String, dynamic>);
  }
}
