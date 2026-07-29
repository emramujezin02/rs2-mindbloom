import '../models/update_user_settings_request.dart';
import '../models/user_settings_model.dart';
import '../services/user_settings_api_service.dart';

class UserSettingsRepository {
  final UserSettingsApiService apiService;

  UserSettingsRepository({required this.apiService});

  Future<UserSettingsModel> getSettings() {
    return apiService.getSettings();
  }

  Future<UserSettingsModel> updateSettings({
    required bool notificationsEnabled,
    required bool showProfilePublicly,
  }) {
    return apiService.updateSettings(
      UpdateUserSettingsRequest(
        notificationsEnabled: notificationsEnabled,
        showProfilePublicly: showProfilePublicly,
      ),
    );
  }
}
