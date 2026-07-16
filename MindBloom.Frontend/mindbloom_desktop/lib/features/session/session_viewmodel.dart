import 'package:flutter/foundation.dart';

import '../auth/data/models/current_user_model.dart';
import '../auth/data/repositories/auth_repository.dart';
import '../../services/session_storage_service.dart';

class SessionViewModel extends ChangeNotifier {
  final SessionStorageService sessionStorage;

  final AuthRepository authRepository;

  SessionViewModel({
    required this.sessionStorage,
    required this.authRepository,
  });

  bool isInitialized = false;

  bool isLoggedIn = false;

  CurrentUserModel? currentUser;

  Future<void> initialize() async {
    isInitialized = false;
    notifyListeners();

    try {
      final hasStoredSession = await sessionStorage.hasAdminSession();

      if (!hasStoredSession) {
        isLoggedIn = false;
        currentUser = null;

        return;
      }

      final user = await authRepository.getCurrentUser();

      if (!user.isAdmin) {
        await sessionStorage.clearSession();

        isLoggedIn = false;
        currentUser = null;

        return;
      }

      currentUser = user;
      isLoggedIn = true;
    } catch (_) {
      await sessionStorage.clearSession();

      currentUser = null;
      isLoggedIn = false;
    } finally {
      isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await authRepository.logout();
    } finally {
      await sessionStorage.clearSession();

      currentUser = null;
      isLoggedIn = false;
      isInitialized = true;

      notifyListeners();
    }
  }
}
