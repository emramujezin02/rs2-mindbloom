import 'package:flutter/material.dart';
import '../../data/models/update_profile_request.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';

class ProfileViewModel extends ChangeNotifier {
  final ProfileRepository repository;

  ProfileViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  ProfileModel? profile;

  Future<void> loadProfile() async {
    isLoading = true;
    error = null;

    notifyListeners();

    try {
      profile = await repository.getProfile();
    } catch (e) {
      error = e.toString();
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
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();

      return false;
    }
  }
}
