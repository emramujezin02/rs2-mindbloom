import 'package:flutter/material.dart';

import '../../data/models/profile_model.dart';
import '../../data/models/update_profile_request.dart';
import '../../data/repositories/profile_repository.dart';

class ProfileViewModel extends ChangeNotifier {
  final ProfileRepository repository;

  ProfileViewModel({required this.repository});

  bool isLoading = false;
  bool isUploadingImage = false;

  String? error;

  ProfileModel? profile;

  Future<void> loadProfile() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      profile = await repository.getProfile();
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      profile = await repository.updateProfile(
        UpdateProfileRequest(
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
        ),
      );

      isLoading = false;
      notifyListeners();

      return true;
    } catch (exception) {
      error = exception.toString();
      isLoading = false;
      notifyListeners();

      return false;
    }
  }

  Future<bool> uploadProfileImage(String filePath) async {
    isUploadingImage = true;
    error = null;
    notifyListeners();

    try {
      profile = await repository.uploadProfileImage(filePath);

      isUploadingImage = false;
      notifyListeners();

      return true;
    } catch (exception) {
      error = exception.toString();
      isUploadingImage = false;
      notifyListeners();

      return false;
    }
  }
}
