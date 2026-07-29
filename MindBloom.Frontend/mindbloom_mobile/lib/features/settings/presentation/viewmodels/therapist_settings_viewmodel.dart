import 'package:flutter/foundation.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/repositories/user_settings_repository.dart';

class TherapistSettingsViewModel extends ChangeNotifier {
  final UserSettingsRepository repository;

  TherapistSettingsViewModel({required this.repository});

  bool isLoading = false;
  bool isSaving = false;

  bool notificationsEnabled = true;
  bool showProfilePublicly = true;

  String? error;

  Future<void> load() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;

    notifyListeners();

    try {
      final settings = await repository.getSettings();

      notificationsEnabled = settings.notificationsEnabled;

      showProfilePublicly = settings.showProfilePublicly;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  void setNotificationsEnabled(bool value) {
    notificationsEnabled = value;

    notifyListeners();
  }

  void setShowProfilePublicly(bool value) {
    showProfilePublicly = value;

    notifyListeners();
  }

  Future<bool> save() async {
    if (isSaving) {
      return false;
    }

    isSaving = true;
    error = null;

    notifyListeners();

    try {
      final settings = await repository.updateSettings(
        notificationsEnabled: notificationsEnabled,
        showProfilePublicly: showProfilePublicly,
      );

      notificationsEnabled = settings.notificationsEnabled;

      showProfilePublicly = settings.showProfilePublicly;

      return true;
    } catch (exception) {
      error = AppErrorMessage.from(exception);

      return false;
    } finally {
      isSaving = false;

      notifyListeners();
    }
  }
}
