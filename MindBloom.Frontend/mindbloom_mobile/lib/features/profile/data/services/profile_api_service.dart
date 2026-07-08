import '../../../../core/network/api_client.dart';
import '../models/profile_model.dart';

class ProfileApiService {
  final ApiClient apiClient;

  ProfileApiService({required this.apiClient});

  Future<ProfileModel> getProfile() async {
    final response = await apiClient.get('/Users/me');

    return ProfileModel.fromJson(response);
  }
}
