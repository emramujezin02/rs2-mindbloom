import '../../../../core/network/api_client.dart';
import '../models/update_user_settings_request.dart';
import '../models/user_settings_model.dart';

class UserSettingsApiService {
  final ApiClient apiClient;

  UserSettingsApiService({required this.apiClient});

  Future<UserSettingsModel> getSettings() async {
    final response = await apiClient.get('/user-settings/me');

    return UserSettingsModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<UserSettingsModel> updateSettings(
    UpdateUserSettingsRequest request,
  ) async {
    final response = await apiClient.put(
      '/user-settings/me',
      body: request.toJson(),
    );

    return UserSettingsModel.fromJson(Map<String, dynamic>.from(response));
  }
}
