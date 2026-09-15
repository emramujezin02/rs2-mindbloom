import 'package:flutter/foundation.dart';

import '../../../../core/error/app_error_helper.dart';
import '../../data/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository repository;

  AuthViewModel({required this.repository});

  bool isLoading = false;

  String? errorMessage;

  Future<bool> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.login(
        email: email.trim(),
        password: password,
        rememberMe: rememberMe,
      );

      return true;
    } catch (error) {
      errorMessage = AppErrorHelper.message(error);

      return false;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    errorMessage = null;

    notifyListeners();
  }
}
