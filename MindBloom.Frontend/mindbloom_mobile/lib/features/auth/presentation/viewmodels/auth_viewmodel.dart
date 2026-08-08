import 'package:flutter/foundation.dart';
import '../../../../core/error/app_exception.dart';
import '../../data/models/change_password_request.dart';
import '../../data/models/forgot_password_request.dart';
import '../../data/models/login_request.dart';
import '../../data/models/register_request.dart';
import '../../data/models/reset_password_request.dart';
import '../../data/models/verify_2fa_request.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/current_consent_versions.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository authRepository;

  AuthViewModel({required this.authRepository});

  bool isLoading = false;
  bool isDeletingAccount = false;

  String? errorMessage;

  String? successMessage;

  CurrentConsentVersions? currentConsentVersions;

  bool isLoadingConsentVersions = false;

  String? consentVersionsError;

  bool get hasRegistrationConsentVersions =>
      currentConsentVersions?.hasRegistrationVersions ?? false;

  Map<String, List<String>> fieldErrors = {};

  bool requiresTwoFactor = false;

  String? pendingTwoFactorEmail;

  String? pendingTwoFactorChallengeToken;

  DateTime? pendingTwoFactorChallengeExpiresAtUtc;

  bool isTwoFactorEnabled = false;

  bool needsEmailVerification = false;

  String? pendingVerificationEmail;

  String? fieldError(String fieldName) {
    final requestedField = _normalizeFieldName(fieldName);

    for (final entry in fieldErrors.entries) {
      final backendField = _normalizeFieldName(entry.key);

      if (backendField == requestedField && entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }

    return null;
  }

  Future<bool> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;

    _clearErrors();

    successMessage = null;

    requiresTwoFactor = false;

    pendingTwoFactorEmail = null;

    pendingTwoFactorChallengeToken = null;

    pendingTwoFactorChallengeExpiresAtUtc = null;

    needsEmailVerification = false;

    pendingVerificationEmail = null;

    notifyListeners();

    try {
      final response = await authRepository.login(
        LoginRequest(email: email, password: password, rememberMe: rememberMe),
      );

      requiresTwoFactor = response.requiresTwoFactor;

      if (requiresTwoFactor) {
        final challengeToken = response.challengeToken;

        if (challengeToken == null || challengeToken.trim().isEmpty) {
          throw Exception(
            'The server did not return a valid two-factor authentication challenge.',
          );
        }

        pendingTwoFactorEmail = email;

        pendingTwoFactorChallengeToken = challengeToken.trim();

        pendingTwoFactorChallengeExpiresAtUtc = response.challengeExpiresAtUtc;

        successMessage = response.message;

        return true;
      }

      /*
     * Za običan login nema aktivnog
     * 2FA challenge-a.
     */
      pendingTwoFactorEmail = null;

      pendingTwoFactorChallengeToken = null;

      pendingTwoFactorChallengeExpiresAtUtc = null;

      return true;
    } catch (error) {
      _setError(error, fallback: 'Prijava nije uspjela.');

      final normalizedError = errorMessage?.toLowerCase() ?? '';

      needsEmailVerification = normalizedError.contains(
        'email is not verified',
      );

      if (needsEmailVerification) {
        pendingVerificationEmail = email;
      }

      return false;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> verify2FA({
    required String challengeToken,
    required String code,
  }) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;

    _clearErrors();

    successMessage = null;

    notifyListeners();

    try {
      await authRepository.verify2FA(
        Verify2FARequest(challengeToken: challengeToken, code: code),
      );

      requiresTwoFactor = false;

      pendingTwoFactorEmail = null;

      pendingTwoFactorChallengeToken = null;

      pendingTwoFactorChallengeExpiresAtUtc = null;

      successMessage = 'Dvofaktorska autentifikacija je uspješno završena.';

      return true;
    } catch (error) {
      _setError(error, fallback: 'Verifikacija koda nije uspjela.');

      return false;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<void> load2FAStatus() async {
    if (isLoading) {
      return;
    }

    isLoading = true;

    _clearErrors();

    notifyListeners();

    try {
      isTwoFactorEnabled = await authRepository.get2FAStatus();
    } catch (error) {
      _setError(
        error,
        fallback: 'Status dvofaktorske autentifikacije nije moguće učitati.',
      );
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> set2FAEnabled({
    required bool enabled,
    required String currentPassword,
  }) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;

    _clearErrors();

    successMessage = null;

    notifyListeners();

    try {
      if (enabled) {
        await authRepository.enable2FA(currentPassword);
      } else {
        await authRepository.disable2FA(currentPassword);
      }

      isTwoFactorEnabled = enabled;

      successMessage = enabled
          ? 'Dvofaktorska autentifikacija je uključena.'
          : 'Dvofaktorska autentifikacija je isključena.';

      return true;
    } catch (error) {
      _setError(
        error,
        fallback:
            'Postavke dvofaktorske autentifikacije nije moguće promijeniti.',
      );

      return false;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required DateTime dateOfBirth,
    required bool acceptPrivacyPolicy,
    required bool acceptTermsOfService,
  }) async {
    if (isLoading) {
      return false;
    }

    final consentVersions = currentConsentVersions;

    if (consentVersions == null || !consentVersions.hasRegistrationVersions) {
      errorMessage = 'Privacy documents could not be loaded. Please try again.';

      notifyListeners();

      return false;
    }

    if (!acceptPrivacyPolicy || !acceptTermsOfService) {
      errorMessage =
          'You must accept the Privacy Policy and Terms of Service to register.';

      notifyListeners();

      return false;
    }

    isLoading = true;

    _clearErrors();

    successMessage = null;

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
          acceptPrivacyPolicy: acceptPrivacyPolicy,
          privacyPolicyVersion: consentVersions.privacyPolicyVersion,
          acceptTermsOfService: acceptTermsOfService,
          termsOfServiceVersion: consentVersions.termsOfServiceVersion,
        ),
      );

      successMessage = 'Registracija je uspješno završena.';

      return true;
    } catch (error) {
      _setError(error, fallback: 'Registracija nije uspjela.');

      return false;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> forgotPassword({required String email}) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;

    _clearErrors();

    successMessage = null;

    notifyListeners();

    try {
      await authRepository.forgotPassword(ForgotPasswordRequest(email: email));

      successMessage = 'Kod za promjenu lozinke poslan je na vaš email.';

      return true;
    } catch (error) {
      _setError(
        error,
        fallback: 'Kod za promjenu lozinke nije moguće poslati.',
      );

      return false;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;

    _clearErrors();

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

      successMessage = 'Lozinka je uspješno promijenjena.';

      return true;
    } catch (error) {
      _setError(error, fallback: 'Lozinku nije moguće promijeniti.');

      return false;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;

    _clearErrors();

    successMessage = null;

    notifyListeners();

    try {
      await authRepository.changePassword(
        ChangePasswordRequest(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmNewPassword: confirmNewPassword,
        ),
      );

      successMessage = 'Lozinka je uspješno promijenjena.';

      return true;
    } catch (error) {
      _setError(error, fallback: 'Lozinku nije moguće promijeniti.');

      return false;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> sendEmailVerificationCode({required String email}) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;

    _clearErrors();

    successMessage = null;

    notifyListeners();

    try {
      await authRepository.sendEmailVerificationCode(email);

      successMessage = 'Novi verifikacijski kod poslan je na vaš email.';

      return true;
    } catch (error) {
      _setError(error, fallback: 'Verifikacijski kod nije moguće poslati.');

      return false;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;

    _clearErrors();

    successMessage = null;

    notifyListeners();

    try {
      await authRepository.verifyEmailCode(email: email, code: code);

      needsEmailVerification = false;
      pendingVerificationEmail = null;

      successMessage = 'Email je uspješno potvrđen. Sada se možete prijaviti.';

      return true;
    } catch (error) {
      _setError(error, fallback: 'Email nije moguće potvrditi.');

      return false;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  void _clearErrors() {
    errorMessage = null;
    fieldErrors = {};
  }

  void _setError(Object error, {required String fallback}) {
    if (error is AppException) {
      errorMessage = error.message.trim().isEmpty
          ? fallback
          : error.message.trim();

      fieldErrors = Map<String, List<String>>.from(error.fieldErrors);

      return;
    }

    final normalizedMessage = error
        .toString()
        .replaceFirst('Exception: ', '')
        .trim();

    errorMessage = normalizedMessage.isEmpty ? fallback : normalizedMessage;
  }

  String _normalizeFieldName(String value) {
    var normalized = value
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toLowerCase();

    const prefixes = ['request', 'model', 'dto'];

    for (final prefix in prefixes) {
      if (normalized.startsWith(prefix)) {
        normalized = normalized.substring(prefix.length);
      }
    }

    return normalized;
  }

  Future<void> loadCurrentConsentVersions() async {
    if (isLoadingConsentVersions) {
      return;
    }

    isLoadingConsentVersions = true;
    consentVersionsError = null;

    notifyListeners();

    try {
      currentConsentVersions = await authRepository.getCurrentConsentVersions();
    } catch (error) {
      currentConsentVersions = null;

      if (error is AppException) {
        final message = error.message.trim();

        consentVersionsError = message.isEmpty
            ? 'Privacy documents could not be loaded.'
            : message;
      } else {
        final message = error.toString().replaceFirst('Exception: ', '').trim();

        consentVersionsError = message.isEmpty
            ? 'Privacy documents could not be loaded.'
            : message;
      }
    } finally {
      isLoadingConsentVersions = false;

      notifyListeners();
    }
  }

  Future<bool> deleteAccount({required String password}) async {
    if (isDeletingAccount) {
      return false;
    }

    if (password.trim().isEmpty) {
      errorMessage = 'Enter your current password to confirm account deletion.';

      notifyListeners();

      return false;
    }

    isDeletingAccount = true;

    _clearErrors();

    successMessage = null;

    notifyListeners();

    try {
      await authRepository.deleteAccount(password: password);

      successMessage = 'Account deleted successfully.';

      return true;
    } catch (error) {
      _setError(error, fallback: 'Account could not be deleted.');

      return false;
    } finally {
      isDeletingAccount = false;

      notifyListeners();
    }
  }
}
