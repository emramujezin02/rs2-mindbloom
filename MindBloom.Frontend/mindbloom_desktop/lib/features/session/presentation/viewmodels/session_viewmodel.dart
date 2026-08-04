import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/session_expiration_notifier.dart';
import '../../../../services/session_storage_service.dart';
import '../../../auth/data/models/current_user_model.dart';
import '../../../auth/data/repositories/auth_repository.dart';

class SessionViewModel extends ChangeNotifier {
  final SessionStorageService sessionStorage;

  final AuthRepository authRepository;

  StreamSubscription<void>? _sessionExpiredSubscription;

  SessionViewModel({
    required this.sessionStorage,
    required this.authRepository,
  }) {
    _sessionExpiredSubscription = SessionExpirationNotifier.stream.listen((_) {
      _handleSessionExpired();
    });
  }

  bool isInitialized = false;

  bool isLoggedIn = false;

  bool sessionExpired = false;

  CurrentUserModel? currentUser;

  Future<void> initialize() async {
    isInitialized = false;
    sessionExpired = false;

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
    sessionExpired = false;

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

  Future<void> _handleSessionExpired() async {
    await sessionStorage.clearSession();

    currentUser = null;
    isLoggedIn = false;
    isInitialized = true;
    sessionExpired = true;

    notifyListeners();
  }

  void clearSessionExpiredFlag() {
    if (!sessionExpired) {
      return;
    }

    sessionExpired = false;

    notifyListeners();
  }

  @override
  void dispose() {
    _sessionExpiredSubscription?.cancel();

    super.dispose();
  }
}
