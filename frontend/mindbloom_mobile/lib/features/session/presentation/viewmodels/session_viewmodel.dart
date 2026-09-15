import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../auth/data/repositories/auth_repository.dart';
import '../../../../services/session_runtime_state_service.dart';
import '../../../../services/session_storage_service.dart';

class SessionViewModel extends ChangeNotifier {
  static const Duration _localSessionTimeout = Duration(seconds: 5);
  static const Duration _runtimeStateTimeout = Duration(seconds: 3);
  static const Duration _sessionEndTimeout = Duration(seconds: 5);
  static const Duration _startupRefreshTimeout = Duration(seconds: 8);

  final SessionStorageService sessionStorage;

  final AuthRepository authRepository;

  final Future<void> Function() onSessionEnded;

  final SessionRuntimeStateService runtimeState;

  final Future<bool> Function({required Duration timeout}) refreshAccessToken;

  final VoidCallback onNavigateToLogin;

  Future<void>? _initializationInProgress;

  Future<void>? _sessionExpirationInProgress;

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
    required this.runtimeState,
    required this.refreshAccessToken,
    required this.onNavigateToLogin,
  });

  Future<void> initialize() {
    final activeInitialization = _initializationInProgress;

    if (activeInitialization != null) {
      return activeInitialization;
    }

    final initialization = _initialize();
    _initializationInProgress = initialization;

    return initialization.whenComplete(() {
      if (identical(_initializationInProgress, initialization)) {
        _initializationInProgress = null;
      }
    });
  }

  Future<void> _initialize() async {
    final stopwatch = Stopwatch()..start();
    var shouldClearLocalSession = false;

    if (kDebugMode) {
      debugPrint(
        'MindBloom session: restore started '
        'at=${DateTime.now().toIso8601String()}',
      );
    }

    try {
      var token = await _withTimeout(
        sessionStorage.getToken(),
        'access token restore',
        _localSessionTimeout,
      );

      var storedRole = await _withTimeout(
        sessionStorage.getUserRole(),
        'user role restore',
        _localSessionTimeout,
      );

      if (token == null || token.trim().isEmpty) {
        _setLoggedOutState();
        return;
      }

      if (_isAccessTokenExpired(token)) {
        if (kDebugMode) {
          debugPrint('MindBloom session: stored access token is expired');
        }

        final refreshed = await refreshAccessToken(
          timeout: _startupRefreshTimeout,
        );

        if (!refreshed) {
          shouldClearLocalSession = true;
          _setLoggedOutState();
          return;
        }

        final refreshedToken = await _withTimeout(
          sessionStorage.getToken(),
          'access token restore after refresh',
          _localSessionTimeout,
        );

        if (refreshedToken == null || refreshedToken.trim().isEmpty) {
          shouldClearLocalSession = true;
          _setLoggedOutState();
          return;
        }

        token = refreshedToken;

        storedRole = await _withTimeout(
          sessionStorage.getUserRole(),
          'user role restore after refresh',
          _localSessionTimeout,
        );
      }

      if (token.trim().isEmpty ||
          storedRole == null ||
          storedRole.trim().isEmpty) {
        shouldClearLocalSession = true;
        _setLoggedOutState();
        return;
      }

      role = storedRole;
      isLoggedIn = true;

      await _resetRuntimeStateSafely();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'MindBloom session: restore failed with '
          '${error.runtimeType}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      shouldClearLocalSession = true;
      _setLoggedOutState();
    } finally {
      if (shouldClearLocalSession) {
        await _clearLocalSessionSafely();
      }

      isInitialized = true;

      if (kDebugMode) {
        debugPrint(
          'MindBloom session: restore finished '
          'isLoggedIn=$isLoggedIn role=${role ?? "none"} '
          'durationMs=${stopwatch.elapsedMilliseconds}',
        );
      }

      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await authRepository.logout();
    } finally {
      await _endLocalSession(navigateToLogin: false);
    }
  }

  Future<void> logoutAll() async {
    try {
      await authRepository.logoutAll();
    } finally {
      await _endLocalSession(navigateToLogin: false);
    }
  }

  Future<void> expireSession() {
    final activeExpiration = _sessionExpirationInProgress;

    if (activeExpiration != null) {
      return activeExpiration;
    }

    final expiration = _endLocalSession(navigateToLogin: true);
    _sessionExpirationInProgress = expiration;

    return expiration.whenComplete(() {
      if (identical(_sessionExpirationInProgress, expiration)) {
        _sessionExpirationInProgress = null;
      }
    });
  }

  Future<void> updateSession({required String role}) async {
    this.role = role;

    isLoggedIn = true;

    isInitialized = true;

    await _withTimeout(
      sessionStorage.saveUserRole(role),
      'user role save',
      _localSessionTimeout,
    );

    await _resetRuntimeStateSafely();

    notifyListeners();
  }

  Future<void> _endLocalSession({required bool navigateToLogin}) async {
    await _notifySessionEndedSafely();

    await _clearLocalSessionSafely();

    await _resetRuntimeStateSafely();

    _setLoggedOutState();

    isInitialized = true;

    notifyListeners();

    if (navigateToLogin) {
      onNavigateToLogin();
    }
  }

  void _setLoggedOutState() {
    role = null;
    isLoggedIn = false;
  }

  Future<void> _notifySessionEndedSafely() async {
    try {
      await onSessionEnded().timeout(_sessionEndTimeout);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'MindBloom session: session-end cleanup failed with '
          '${error.runtimeType}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> _clearLocalSessionSafely() async {
    try {
      await _withTimeout(
        sessionStorage.clearSession(),
        'local session cleanup',
        _localSessionTimeout,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'MindBloom session: local cleanup failed with '
          '${error.runtimeType}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> _resetRuntimeStateSafely() async {
    try {
      await _withTimeout(
        runtimeState.resetAuthenticatedUiState(),
        'runtime UI state reset',
        _runtimeStateTimeout,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'MindBloom session: runtime UI reset failed with '
          '${error.runtimeType}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<T> _withTimeout<T>(
    Future<T> future,
    String operation,
    Duration timeout,
  ) {
    return future.timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException(
          'MindBloom session operation timed out: $operation',
          timeout,
        );
      },
    );
  }

  bool _isAccessTokenExpired(String token) {
    final parts = token.split('.');

    if (parts.length != 3) {
      return false;
    }

    try {
      final payloadJson = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final payload = jsonDecode(payloadJson);

      if (payload is! Map<String, dynamic>) {
        return false;
      }

      final exp = payload['exp'];
      final expSeconds = exp is int ? exp : int.tryParse(exp?.toString() ?? '');

      if (expSeconds == null) {
        return false;
      }

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        expSeconds * 1000,
        isUtc: true,
      );
      final refreshWindowStart = expiresAt.subtract(
        const Duration(seconds: 30),
      );

      return !DateTime.now().toUtc().isBefore(refreshWindowStart);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'MindBloom session: access token expiry check failed with '
          '${error.runtimeType}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      return false;
    }
  }
}
