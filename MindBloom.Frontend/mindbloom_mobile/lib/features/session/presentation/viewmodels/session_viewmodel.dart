import 'package:flutter/foundation.dart';

import '../../../auth/data/repositories/auth_repository.dart';
import '../../../../services/session_storage_service.dart';

class SessionViewModel extends ChangeNotifier {
  final SessionStorageService sessionStorage;
  final AuthRepository authRepository;

  bool isInitialized = false;
  bool isLoggedIn = false;
  String? role;
  bool get isClient => role == 'Client';
  bool get isTherapist => role == 'Therapist';
  bool get isAdmin => role == 'Admin';

  SessionViewModel({
    required this.sessionStorage,
    required this.authRepository,
  });

  Future<void> initialize() async {
    final token = await sessionStorage.getToken();

    role = await sessionStorage.getUserRole();

    isLoggedIn = token != null && token.trim().isNotEmpty;

    isInitialized = true;

    notifyListeners();
  }

  Future<void> logout() async {
    await authRepository.logout();

    await sessionStorage.clearSession();

    role = null;

    isLoggedIn = false;

    notifyListeners();
  }

  Future<void> updateSession({required String role}) async {
    this.role = role;

    isLoggedIn = true;

    await sessionStorage.saveUserRole(role);

    notifyListeners();
  }
}
