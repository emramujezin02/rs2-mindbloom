import 'package:flutter/foundation.dart';

import '../../../auth/data/repositories/auth_repository.dart';
import '../../../../services/session_storage_service.dart';

class SessionViewModel extends ChangeNotifier {
  final SessionStorageService sessionStorage;
  final AuthRepository authRepository;

  bool isInitialized = false;
  bool isLoggedIn = false;

  SessionViewModel({
    required this.sessionStorage,
    required this.authRepository,
  });

  Future<void> initialize() async {
    final token = await sessionStorage.getToken();

    isLoggedIn = token != null && token.trim().isNotEmpty;

    isInitialized = true;

    notifyListeners();
  }

  Future<void> logout() async {
    await authRepository.logout();

    isLoggedIn = false;

    notifyListeners();
  }
}
