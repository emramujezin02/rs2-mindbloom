import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/admin_account_settings_model.dart';
import '../models/admin_application_info_model.dart';
import '../models/admin_profile_model.dart';
import '../services/admin_settings_api_service.dart';

class AdminSettingsRepository {
  final AdminSettingsApiService apiService;

  const AdminSettingsRepository({required this.apiService});

  Future<AdminProfileModel> getProfile() {
    return apiService.getProfile();
  }

  Future<AdminProfileModel> updateProfile({
    required String firstName,
    required String lastName,
    required String? phoneNumber,
    required DateTime dateOfBirth,
  }) {
    return apiService.updateProfile(
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      dateOfBirth: dateOfBirth,
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return apiService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<AdminAccountSettingsModel> getAccountSettings() {
    return apiService.getAccountSettings();
  }

  Future<AdminAccountSettingsModel> updateAccountSettings({
    required bool notificationsEnabled,
    required bool showProfilePublicly,
  }) {
    return apiService.updateAccountSettings(
      notificationsEnabled: notificationsEnabled,
      showProfilePublicly: showProfilePublicly,
    );
  }

  Future<AdminApplicationInfoModel> getApplicationInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();

    /*
     * Environment is intentionally available
     * only in debug/development builds.
     *
     * Release builds return null and therefore
     * never expose an environment label or any
     * underlying configuration.
     */
    final environment = kDebugMode
        ? const String.fromEnvironment('APP_ENV', defaultValue: 'Development')
        : null;

    return AdminApplicationInfoModel(
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      environment: environment,
    );
  }
}
