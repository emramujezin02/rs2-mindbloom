import 'package:flutter/foundation.dart';

import '../../../../core/error/app_error_helper.dart';
import '../../data/models/admin_account_settings_model.dart';
import '../../data/models/admin_application_info_model.dart';
import '../../data/models/admin_profile_model.dart';
import '../../data/repositories/admin_settings_repository.dart';

class AdminSettingsViewModel extends ChangeNotifier {
  final AdminSettingsRepository repository;

  AdminSettingsViewModel({required this.repository});

  bool isLoading = false;

  bool isSavingProfile = false;

  bool isChangingPassword = false;

  bool isSavingNotifications = false;

  String? errorMessage;

  AdminProfileModel? profile;

  AdminAccountSettingsModel? accountSettings;

  AdminApplicationInfoModel? applicationInfo;

  bool get isBusy =>
      isSavingProfile || isChangingPassword || isSavingNotifications;

  Future<void> initialize() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        repository.getProfile(),
        repository.getAccountSettings(),
        repository.getApplicationInfo(),
      ]);

      profile = results[0] as AdminProfileModel;

      accountSettings = results[1] as AdminAccountSettingsModel;

      applicationInfo = results[2] as AdminApplicationInfoModel;
    } catch (error) {
      errorMessage = AppErrorHelper.message(error);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String? phoneNumber,
  }) async {
    if (isSavingProfile) {
      return false;
    }

    final currentProfile = profile;

    if (currentProfile == null) {
      errorMessage = 'Profil administratora nije učitan.';

      notifyListeners();

      return false;
    }

    isSavingProfile = true;
    errorMessage = null;

    notifyListeners();

    try {
      profile = await repository.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        dateOfBirth: currentProfile.dateOfBirth,
      );

      return true;
    } catch (error) {
      errorMessage = AppErrorHelper.message(error);

      return false;
    } finally {
      isSavingProfile = false;

      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (isChangingPassword) {
      return false;
    }

    isChangingPassword = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      return true;
    } catch (error) {
      errorMessage = AppErrorHelper.message(error);

      return false;
    } finally {
      isChangingPassword = false;

      notifyListeners();
    }
  }

  Future<bool> setNotificationsEnabled(bool value) async {
    if (isSavingNotifications) {
      return false;
    }

    final currentSettings = accountSettings;

    if (currentSettings == null) {
      errorMessage = 'Postavke notifikacija nisu učitane.';

      notifyListeners();

      return false;
    }

    isSavingNotifications = true;
    errorMessage = null;

    notifyListeners();

    try {
      accountSettings = await repository.updateAccountSettings(
        notificationsEnabled: value,

        /*
         * Admin UI does not expose the public
         * profile preference. Preserve the
         * existing server value.
         */
        showProfilePublicly: currentSettings.showProfilePublicly,
      );

      return true;
    } catch (error) {
      errorMessage = AppErrorHelper.message(error);

      return false;
    } finally {
      isSavingNotifications = false;

      notifyListeners();
    }
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    errorMessage = null;

    notifyListeners();
  }
}
