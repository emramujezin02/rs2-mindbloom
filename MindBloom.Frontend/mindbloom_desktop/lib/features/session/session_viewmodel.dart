import 'package:flutter/foundation.dart';

import '../../services/session_storage_service.dart';

class SessionViewModel extends ChangeNotifier {
  final SessionStorageService sessionStorage;

  bool isInitialized = false;
  bool isLoggedIn = false;

  SessionViewModel({required this.sessionStorage});

  Future<void> initialize() async {
    final token = await sessionStorage.getToken();

    isLoggedIn = token != null;
    isInitialized = true;

    notifyListeners();
  }

  Future<void> logout() async {
    await sessionStorage.clear();

    isLoggedIn = false;

    notifyListeners();
  }
}
