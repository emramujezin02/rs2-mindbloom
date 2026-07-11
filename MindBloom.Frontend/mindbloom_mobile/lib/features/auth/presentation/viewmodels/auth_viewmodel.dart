import 'package:flutter/foundation.dart';

import '../../data/models/change_password_request.dart';
import '../../data/models/forgot_password_request.dart';
import '../../data/models/login_request.dart';
import '../../data/models/register_request.dart';
import '../../data/models/reset_password_request.dart';
import '../../data/models/verify_2fa_request.dart';
import '../../data/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository authRepository;

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  bool requiresTwoFactor = false;
  String? pendingTwoFactorEmail;

  bool isTwoFactorEnabled = false;

  AuthViewModel({required this.authRepository});

  Future<bool> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    requiresTwoFactor = false;
    pendingTwoFactorEmail = null;
    notifyListeners();

    try {
      final response = await authRepository.login(
        LoginRequest(email: email, password: password, rememberMe: rememberMe),
      );

      requiresTwoFactor = response.requiresTwoFactor;

      if (requiresTwoFactor) {
        pendingTwoFactorEmail = email;
        successMessage = response.message;
      }

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

  Future<bool> verify2FA({required String email, required String code}) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await authRepository.verify2FA(
        Verify2FARequest(email: email, code: code),
      );

      requiresTwoFactor = false;
      pendingTwoFactorEmail = null;
      isLoading = false;
      successMessage = 'Two-factor authentication completed.';
      notifyListeners();

      return true;
    } catch (error) {
      isLoading = false;
      errorMessage = error.toString();
      notifyListeners();

      return false;
    }
  }

  Future<void> load2FAStatus() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      isTwoFactorEnabled = await authRepository.get2FAStatus();
    } catch (error) {
      errorMessage = error.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> set2FAEnabled(bool enabled) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      if (enabled) {
        await authRepository.enable2FA();
      } else {
        await authRepository.disable2FA();
      }

      isTwoFactorEnabled = enabled;
      isLoading = false;
      successMessage = enabled
          ? 'Two-factor authentication enabled.'
          : 'Two-factor authentication disabled.';
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

  Future<bool> forgotPassword({required String email}) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await authRepository.forgotPassword(ForgotPasswordRequest(email: email));

      isLoading = false;
      successMessage = 'Password reset code has been sent to your email.';
      notifyListeners();
      return true;
    } catch (error) {
      isLoading = false;
      errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await authRepository.resetPassword(
        ResetPasswordRequest(
          email: email,
          code: code,
          newPassword: newPassword,
        ),
      );

      isLoading = false;
      successMessage = 'Password has been reset successfully.';
      notifyListeners();
      return true;
    } catch (error) {
      isLoading = false;
      errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await authRepository.changePassword(
        ChangePasswordRequest(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );

      isLoading = false;
      successMessage = 'Password changed successfully.';
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
