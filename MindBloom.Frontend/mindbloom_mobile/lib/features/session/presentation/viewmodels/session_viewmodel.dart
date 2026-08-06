import 'package:flutter/foundation.dart';

import '../../../auth/data/repositories/auth_repository.dart';
import '../../../../services/session_storage_service.dart';

class SessionViewModel extends ChangeNotifier {
  final SessionStorageService sessionStorage;

  final AuthRepository authRepository;

  final Future<void> Function() onSessionEnded;

  bool isInitialized = false;

  bool isLoggedIn = false;

  String? role;

  bool get isClient => role == 'Client';

  bool get isTherapist => role == 'Therapist';

  bool get isAdmin => role == 'Admin';

  SessionViewModel({
    required this.sessionStorage,
    required this.authRepository,
    required this.onSessionEnded,
  });

  Future<void> initialize() async {
    final token = await sessionStorage.getToken();

    role = await sessionStorage.getUserRole();

    isLoggedIn = token != null && token.trim().isNotEmpty;

    isInitialized = true;

    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await authRepository.logout();
    } finally {
      /*
       * Čak i ako backend nije dostupan,
       * lokalna sesija i realtime
       * konekcije moraju biti ugašene.
       */
      await onSessionEnded();

      await sessionStorage.clearSession();

      role = null;

      isLoggedIn = false;

      notifyListeners();
    }
  }

  Future<void> logoutAll() async {
    try {
      await authRepository.logoutAll();
    } finally {
      await onSessionEnded();

      await sessionStorage.clearSession();

      role = null;

      isLoggedIn = false;

      notifyListeners();
    }
  }

  Future<void> updateSession({required String role}) async {
    this.role = role;

    isLoggedIn = true;

    await sessionStorage.saveUserRole(role);

    notifyListeners();
  }
}
