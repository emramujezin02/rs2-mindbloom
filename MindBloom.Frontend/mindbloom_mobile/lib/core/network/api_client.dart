import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../services/session_storage_service.dart';
import '../constants/api_constants.dart';
import '../debug/mindbloom_debug_log.dart';
import '../error/app_exception.dart';
import '../navigation/app_navigation.dart';

class ApiClient {
  static const Duration _requestTimeout = Duration(seconds: 30);

  final SessionStorageService sessionStorage;

  Future<void> Function()? onSessionExpired;

  final http.Client _httpClient = http.Client();

  Future<bool>? _refreshInProgress;

  Future<void>? _sessionExpirationInProgress;

  ApiClient({required this.sessionStorage, this.onSessionExpired});

  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    final uri = _buildUri(endpoint);

    return _executeRequest(
      method: 'GET',
      uri: uri,
      requiresAuth: requiresAuth,
      request: () async {
        return _httpClient
            .get(uri, headers: await _headers(requiresAuth: requiresAuth))
            .timeout(_requestTimeout);
      },
    );
  }

  Future<dynamic> post(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
    String? idempotencyKey,
  }) async {
    final uri = _buildUri(endpoint);

    return _executeRequest(
      method: 'POST',
      uri: uri,
      requiresAuth: requiresAuth,
      request: () async {
        final headers = await _headers(requiresAuth: requiresAuth);

        final normalizedIdempotencyKey = idempotencyKey?.trim();

        if (normalizedIdempotencyKey != null &&
            normalizedIdempotencyKey.isNotEmpty) {
          headers['Idempotency-Key'] = normalizedIdempotencyKey;
        }

        final encodedBody = body == null ? null : jsonEncode(body);

        return _httpClient
            .post(uri, headers: headers, body: encodedBody, encoding: utf8)
            .timeout(_requestTimeout);
      },
    );
  }

  Future<dynamic> put(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(endpoint);

    return _executeRequest(
      method: 'PUT',
      uri: uri,
      requiresAuth: requiresAuth,
      request: () async {
        return _httpClient
            .put(
              uri,
              headers: await _headers(requiresAuth: requiresAuth),
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(_requestTimeout);
      },
    );
  }

  Future<dynamic> delete(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(endpoint);

    return _executeRequest(
      method: 'DELETE',
      uri: uri,
      requiresAuth: requiresAuth,
      request: () async {
        final request = http.Request('DELETE', uri);

        request.headers.addAll(await _headers(requiresAuth: requiresAuth));

        if (body != null) {
          request.body = jsonEncode(body);
        }

        final streamedResponse = await _httpClient
            .send(request)
            .timeout(_requestTimeout);

        return http.Response.fromStream(
          streamedResponse,
        ).timeout(_requestTimeout);
      },
    );
  }

  Future<dynamic> multipartPost(
    String endpoint, {
    required String filePath,
    String fileFieldName = 'file',
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(endpoint);

    return _executeRequest(
      method: 'POST multipart',
      uri: uri,
      requiresAuth: requiresAuth,
      request: () async {
        final request = http.MultipartRequest('POST', uri);

        final headers = await _headers(requiresAuth: requiresAuth);

        headers.remove('Content-Type');

        request.headers.addAll(headers);

        request.files.add(
          await http.MultipartFile.fromPath(fileFieldName, filePath),
        );

        final streamedResponse = await _httpClient
            .send(request)
            .timeout(_requestTimeout);

        return http.Response.fromStream(
          streamedResponse,
        ).timeout(_requestTimeout);
      },
    );
  }

  Future<dynamic> _executeRequest({
    required String method,
    required Uri uri,
    required bool requiresAuth,
    required Future<http.Response> Function() request,
  }) async {
    final stopwatch = Stopwatch()..start();
    final requestId = nextHttpRequestId();

    try {
      final tokenPresent = await _hasStoredAccessToken();

      _logDevelopmentRequest(
        requestId,
        method,
        uri,
        requiresAuth: requiresAuth,
        tokenPresent: tokenPresent,
        refreshInProgress: _refreshInProgress != null,
      );

      final response = await _sendWithDevelopmentFailureLog(
        requestId,
        method,
        uri,
        stopwatch,
        attempt: 1,
        request: request,
      );

      _logDevelopmentResponse(
        requestId,
        method,
        uri,
        response.statusCode,
        stopwatch,
        attempt: 1,
      );

      if (response.statusCode != 401 || !requiresAuth) {
        return _handleResponse(response);
      }

      logHttp(
        requestId,
        '401 received; attempting refresh before retry ${_describeUri(uri)}',
      );

      final refreshed = await _refreshAccessToken();

      if (!refreshed) {
        logHttp(requestId, 'refresh failed; expiring local session');
        await _expireSession();

        return _handleResponse(response);
      }

      logHttp(requestId, 'refresh succeeded; retrying original request');

      final repeatedResponse = await _sendWithDevelopmentFailureLog(
        requestId,
        method,
        uri,
        stopwatch,
        attempt: 2,
        request: request,
      );

      _logDevelopmentResponse(
        requestId,
        method,
        uri,
        repeatedResponse.statusCode,
        stopwatch,
        attempt: 2,
      );

      if (repeatedResponse.statusCode == 401) {
        logHttp(requestId, 'retry returned 401; expiring local session');
        await _expireSession();
      }

      return _handleResponse(repeatedResponse);
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException(
        message: 'Server nije odgovorio dovoljno brzo. Pokušajte ponovo.',
      );
    } on SocketException catch (error) {
      if (_isConnectionRefused(error.toString())) {
        throw const AppException(
          message:
              'Server nije dostupan. Provjerite da li je MindBloom.API pokrenut.',
        );
      }

      throw const AppException(
        message:
            'Nema internet veze. Provjerite mrežnu vezu i pokušajte ponovo.',
      );
    } on http.ClientException catch (error) {
      if (_isConnectionRefused(error.toString())) {
        throw const AppException(
          message:
              'Server nije dostupan. Provjerite da li je MindBloom.API pokrenut.',
        );
      }

      throw const AppException(
        message:
            'Povezivanje sa serverom nije uspjelo. Provjerite internet vezu i pokušajte ponovo.',
      );
    } catch (_) {
      throw const AppException(
        message: 'Zahtjev nije moguće izvršiti. Pokušajte ponovo.',
      );
    }
  }

  Future<bool> refreshAccessToken({Duration timeout = _requestTimeout}) {
    return _refreshAccessToken(timeout: timeout);
  }

  Future<bool> _refreshAccessToken({Duration timeout = _requestTimeout}) async {
    final existingRefresh = _refreshInProgress;

    if (existingRefresh != null) {
      return existingRefresh;
    }

    final refreshFuture = _performTokenRefresh(timeout: timeout);

    _refreshInProgress = refreshFuture;

    try {
      return await refreshFuture;
    } finally {
      _refreshInProgress = null;
    }
  }

  Future<bool> _performTokenRefresh({required Duration timeout}) async {
    final refreshRequestId = nextRefreshRequestId();
    final stopwatch = Stopwatch()..start();

    logRefresh(
      refreshRequestId,
      'START POST ${_describeUri(_buildUri('/Auth/refresh-token'))} '
      'refreshTokenPresent=unknown',
    );

    try {
      final refreshToken = await sessionStorage.getRefreshToken().timeout(
        timeout,
      );
      final refreshTokenPresent =
          refreshToken != null && refreshToken.trim().isNotEmpty;

      logRefresh(
        refreshRequestId,
        'TOKEN READ refreshTokenPresent=$refreshTokenPresent '
        'durationMs=${stopwatch.elapsedMilliseconds}',
      );

      if (refreshToken == null || refreshToken.trim().isEmpty) {
        logRefresh(refreshRequestId, 'SKIP missing refresh token');
        return false;
      }

      final response = await _httpClient
          .post(
            _buildUri('/Auth/refresh-token'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken.trim()}),
          )
          .timeout(timeout);

      logRefresh(
        refreshRequestId,
        'END status=${response.statusCode} '
        'durationMs=${stopwatch.elapsedMilliseconds}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      if (response.body.trim().isEmpty) {
        return false;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final newAccessToken = decoded['token'];
      final newRefreshToken = decoded['refreshToken'];

      if (newAccessToken is! String || newAccessToken.trim().isEmpty) {
        return false;
      }

      if (newRefreshToken is! String || newRefreshToken.trim().isEmpty) {
        return false;
      }

      await sessionStorage
          .saveTokens(
            accessToken: newAccessToken.trim(),
            refreshToken: newRefreshToken.trim(),
          )
          .timeout(timeout);

      logRefresh(
        refreshRequestId,
        'TOKENS SAVED durationMs=${stopwatch.elapsedMilliseconds}',
      );

      return true;
    } on TimeoutException catch (error) {
      logRefresh(
        refreshRequestId,
        'FAIL TimeoutException: $error '
        'durationMs=${stopwatch.elapsedMilliseconds}',
      );
      return false;
    } on SocketException catch (error) {
      logRefresh(
        refreshRequestId,
        'FAIL SocketException: $error '
        'durationMs=${stopwatch.elapsedMilliseconds}',
      );
      return false;
    } on FormatException catch (error) {
      logRefresh(
        refreshRequestId,
        'FAIL FormatException: $error '
        'durationMs=${stopwatch.elapsedMilliseconds}',
      );
      return false;
    } on http.ClientException catch (error) {
      logRefresh(
        refreshRequestId,
        'FAIL ClientException: $error '
        'durationMs=${stopwatch.elapsedMilliseconds}',
      );
      return false;
    } catch (error) {
      logRefresh(
        refreshRequestId,
        'FAIL ${error.runtimeType}: $error '
        'durationMs=${stopwatch.elapsedMilliseconds}',
      );
      return false;
    }
  }

  Future<void> _expireSession() async {
    final activeExpiration = _sessionExpirationInProgress;

    if (activeExpiration != null) {
      return activeExpiration;
    }

    final expiration = _performSessionExpiration();
    _sessionExpirationInProgress = expiration;

    return expiration.whenComplete(() {
      if (identical(_sessionExpirationInProgress, expiration)) {
        _sessionExpirationInProgress = null;
      }
    });
  }

  Future<void> _performSessionExpiration() async {
    final sessionExpired = onSessionExpired;

    if (sessionExpired != null) {
      await sessionExpired();
      return;
    }

    await sessionStorage.clearSession();

    AppNavigation.goToLogin();
  }

  Uri _buildUri(String endpoint) {
    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '/$endpoint';

    return Uri.parse('${ApiConstants.apiBaseUrl}$normalizedEndpoint');
  }

  Future<http.Response> _sendWithDevelopmentFailureLog(
    int requestId,
    String method,
    Uri uri,
    Stopwatch stopwatch, {
    required int attempt,
    required Future<http.Response> Function() request,
  }) async {
    try {
      return await request();
    } catch (error) {
      _logDevelopmentFailure(
        requestId,
        method,
        uri,
        error,
        stopwatch,
        attempt: attempt,
      );

      rethrow;
    }
  }

  String _describeUri(Uri uri) {
    final buffer = StringBuffer()
      ..write(uri.scheme)
      ..write('://')
      ..write(uri.host);

    if (uri.hasPort) {
      buffer
        ..write(':')
        ..write(uri.port);
    }

    buffer.write(uri.path);

    if (uri.queryParameters.isNotEmpty) {
      buffer
        ..write('?queryKeys=')
        ..write(uri.queryParameters.keys.join(','));
    }

    return buffer.toString();
  }

  bool _isConnectionRefused(String message) {
    return message.toLowerCase().contains('connection refused');
  }

  void _logDevelopmentRequest(
    int requestId,
    String method,
    Uri uri, {
    required bool requiresAuth,
    required bool tokenPresent,
    required bool refreshInProgress,
  }) {
    if (!kDebugMode) {
      return;
    }

    logHttp(
      requestId,
      'START $method ${_describeUri(uri)} '
      'requiresAuth=$requiresAuth tokenPresent=$tokenPresent '
      'refreshInProgress=$refreshInProgress',
    );
  }

  void _logDevelopmentResponse(
    int requestId,
    String method,
    Uri uri,
    int statusCode,
    Stopwatch stopwatch, {
    required int attempt,
  }) {
    if (!kDebugMode) {
      return;
    }

    logHttp(
      requestId,
      'END attempt=$attempt $method ${_describeUri(uri)} -> $statusCode '
      'durationMs=${stopwatch.elapsedMilliseconds}',
    );
  }

  void _logDevelopmentFailure(
    int requestId,
    String method,
    Uri uri,
    Object error,
    Stopwatch stopwatch, {
    required int attempt,
  }) {
    if (!kDebugMode) {
      return;
    }

    logHttp(
      requestId,
      'FAIL attempt=$attempt $method ${_describeUri(uri)} -> '
      '${error.runtimeType}: $error '
      'durationMs=${stopwatch.elapsedMilliseconds}',
    );
  }

  Future<bool> _hasStoredAccessToken() async {
    final token = await sessionStorage.getToken();

    return token != null && token.trim().isNotEmpty;
  }

  Future<Map<String, String>> _headers({required bool requiresAuth}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (!requiresAuth) {
      return headers;
    }

    final token = await sessionStorage.getToken();

    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) {
        return null;
      }

      try {
        return jsonDecode(response.body);
      } on FormatException {
        return response.body;
      }
    }

    final errorData = _extractErrorData(response);

    throw AppException(
      message: errorData.message,
      statusCode: response.statusCode,
      fieldErrors: errorData.fieldErrors,
    );
  }

  _ApiErrorData _extractErrorData(http.Response response) {
    if (response.body.trim().isEmpty) {
      return _ApiErrorData(message: _defaultErrorMessage(response.statusCode));
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final fieldErrors = _extractFieldErrors(decoded['errors']);

        final directMessage = _readMessage(decoded['message']);
        final title = _readMessage(decoded['title']);
        final detail = _readMessage(decoded['detail']);

        final message =
            directMessage ??
            detail ??
            title ??
            (fieldErrors.isNotEmpty
                ? 'Provjerite označena polja.'
                : _defaultErrorMessage(response.statusCode));

        return _ApiErrorData(message: message, fieldErrors: fieldErrors);
      }

      if (decoded is String && decoded.trim().isNotEmpty) {
        return _ApiErrorData(message: decoded.trim());
      }
    } on FormatException {
      final body = response.body.trim();

      if (body.isNotEmpty) {
        return _ApiErrorData(message: body);
      }
    }

    return _ApiErrorData(message: _defaultErrorMessage(response.statusCode));
  }

  Map<String, List<String>> _extractFieldErrors(dynamic rawErrors) {
    if (rawErrors is! Map) {
      return {};
    }

    final result = <String, List<String>>{};

    for (final entry in rawErrors.entries) {
      final fieldName = entry.key.toString();
      final value = entry.value;
      final messages = <String>[];

      if (value is List) {
        messages.addAll(
          value
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty),
        );
      } else if (value != null) {
        final message = value.toString().trim();

        if (message.isNotEmpty) {
          messages.add(message);
        }
      }

      if (messages.isNotEmpty) {
        result[fieldName] = messages;
      }
    }

    return result;
  }

  String? _readMessage(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  String _defaultErrorMessage(int statusCode) {
    return switch (statusCode) {
      400 => 'Zahtjev sadrži neispravne podatke.',
      401 => 'Sesija je istekla. Prijavite se ponovo.',
      403 => 'Nemate dozvolu za ovu radnju.',
      404 => 'Traženi podatak nije pronađen.',
      408 => 'Zahtjev je istekao. Pokušajte ponovo.',
      409 => 'Radnja se ne može završiti zbog konflikta podataka.',
      422 => 'Provjerite unesene podatke.',
      429 => 'Previše pokušaja. Pokušajte ponovo kasnije.',
      502 ||
      503 ||
      504 => 'Server trenutno nije dostupan. Pokušajte ponovo kasnije.',
      >= 500 => 'Došlo je do greške na serveru. Pokušajte ponovo.',
      _ => 'Zahtjev nije uspješno izvršen.',
    };
  }
}

class _ApiErrorData {
  final String message;
  final Map<String, List<String>> fieldErrors;

  const _ApiErrorData({required this.message, this.fieldErrors = const {}});
}
