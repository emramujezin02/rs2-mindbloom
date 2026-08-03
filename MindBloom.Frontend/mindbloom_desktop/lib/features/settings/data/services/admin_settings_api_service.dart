import '../../../../core/network/api_client.dart';
import '../models/admin_account_settings_model.dart';
import '../models/admin_profile_model.dart';

class AdminSettingsApiService {
  final ApiClient apiClient;

  const AdminSettingsApiService({required this.apiClient});

  Future<AdminProfileModel> getProfile() async {
    final response = await apiClient.get('/api/Users/me');

    if (response is! Map) {
      throw const FormatException(
        'Server je vratio neispravne podatke profila.',
      );
    }

    return AdminProfileModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<AdminProfileModel> updateProfile({
    required String firstName,
    required String lastName,
    required String? phoneNumber,
    required DateTime dateOfBirth,
  }) async {
    final response = await apiClient.put(
      '/api/Users/me',
      body: {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phoneNumber': phoneNumber == null || phoneNumber.trim().isEmpty
            ? null
            : phoneNumber.trim(),

        /*
         * Date of birth is required by the
         * existing shared profile API.
         * Admin settings do not edit it, so
         * we preserve the already loaded value.
         */
        'dateOfBirth': dateOfBirth.toIso8601String(),

        'location': null,
        'preferredTherapistGender': null,
        'preferredSessionType': null,
        'minimumPricePerSession': null,
        'maximumPricePerSession': null,
        'preferredLanguages': <String>[],
      },
    );

    if (response is! Map) {
      throw const FormatException(
        'Server je vratio neispravne podatke profila.',
      );
    }

    return AdminProfileModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await apiClient.post(
      '/api/Auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<AdminAccountSettingsModel> getAccountSettings() async {
    final response = await apiClient.get('/api/user-settings/me');

    if (response is! Map) {
      throw const FormatException(
        'Server je vratio neispravne postavke naloga.',
      );
    }

    return AdminAccountSettingsModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<AdminAccountSettingsModel> updateAccountSettings({
    required bool notificationsEnabled,
    required bool showProfilePublicly,
  }) async {
    final response = await apiClient.put(
      '/api/user-settings/me',
      body: {
        'notificationsEnabled': notificationsEnabled,
        'showProfilePublicly': showProfilePublicly,
      },
    );

    if (response is! Map) {
      throw const FormatException(
        'Server je vratio neispravne postavke naloga.',
      );
    }

    return AdminAccountSettingsModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }
}
