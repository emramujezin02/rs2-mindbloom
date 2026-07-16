import 'package:flutter/foundation.dart';

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
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await repository.login(
        email: email.trim(),
        password: password,
        rememberMe: rememberMe,
      );

      isLoading = false;
      notifyListeners();

      return true;
    } catch (error) {
      errorMessage = _cleanError(error);

      isLoading = false;
      notifyListeners();

      return false;
    }
  }

  String _cleanError(Object error) {
    final value = error.toString();

    if (value.startsWith('Exception: ')) {
      return value.substring('Exception: '.length);
    }

    return value;
  }
}
