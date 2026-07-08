import 'package:flutter/material.dart';

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
}
