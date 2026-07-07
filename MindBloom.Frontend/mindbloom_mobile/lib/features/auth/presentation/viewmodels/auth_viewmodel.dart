import 'package:flutter/foundation.dart';

import '../../data/models/login_request.dart';
import '../../data/models/register_request.dart';
import '../../data/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository authRepository;

  bool isLoading = false;
  String? errorMessage;

  AuthViewModel({required this.authRepository});

  Future<bool> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await authRepository.login(
        LoginRequest(email: email, password: password, rememberMe: rememberMe),
      );

      isLoading = false;
      notifyListeners();

      return true;
    } catch (error) {
      isLoading = false;
      errorMessage = error.toString();
      notifyListeners();

      return false;
    }
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required DateTime dateOfBirth,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await authRepository.register(
        RegisterRequest(
          firstName: firstName,
          lastName: lastName,
          username: username,
          email: email,
          password: password,
          dateOfBirth: dateOfBirth,
        ),
      );

      isLoading = false;
      notifyListeners();

      return true;
    } catch (error) {
      isLoading = false;
      errorMessage = error.toString();
      notifyListeners();

      return false;
    }
  }
}
