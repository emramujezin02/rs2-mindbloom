import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../services/session_storage_service.dart';
import '../constants/api_constants.dart';
import '../error/app_exception.dart';
import '../navigation/app_navigation.dart';

class ApiClient {
  static const Duration _requestTimeout = Duration(seconds: 30);

  final SessionStorageService sessionStorage;

  Future<bool>? _refreshInProgress;

  ApiClient({required this.sessionStorage});

  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    return _executeRequest(
      requiresAuth: requiresAuth,
      request: () async {
        return http
            .get(
              _buildUri(endpoint),
              headers: await _headers(requiresAuth: requiresAuth),
            )
            .timeout(_requestTimeout);
      },
    );
  }

  Future<dynamic> post(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    return _executeRequest(
      requiresAuth: requiresAuth,
      request: () async {
        return http
            .post(
              _buildUri(endpoint),
              headers: await _headers(requiresAuth: requiresAuth),
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(_requestTimeout);
      },
    );
  }

  Future<dynamic> put(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    return _executeRequest(
      requiresAuth: requiresAuth,
      request: () async {
        return http
            .put(
              _buildUri(endpoint),
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
    return _executeRequest(
      requiresAuth: requiresAuth,
      request: () async {
        final request = http.Request('DELETE', _buildUri(endpoint));

        request.headers.addAll(await _headers(requiresAuth: requiresAuth));

        if (body != null) {
          request.body = jsonEncode(body);
        }

        final streamedResponse = await request.send().timeout(_requestTimeout);

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
    return _executeRequest(
      requiresAuth: requiresAuth,
      request: () async {
        final request = http.MultipartRequest('POST', _buildUri(endpoint));

        final headers = await _headers(requiresAuth: requiresAuth);

        headers.remove('Content-Type');

        request.headers.addAll(headers);

        request.files.add(
          await http.MultipartFile.fromPath(fileFieldName, filePath),
        );

        final streamedResponse = await request.send().timeout(_requestTimeout);

        return http.Response.fromStream(
          streamedResponse,
        ).timeout(_requestTimeout);
      },
    );
  }

  Future<dynamic> _executeRequest({
    required bool requiresAuth,
    required Future<http.Response> Function() request,
  }) async {
    try {
      final response = await request();

      if (response.statusCode != 401 || !requiresAuth) {
        return _handleResponse(response);
      }

      final refreshed = await _refreshAccessToken();

      if (!refreshed) {
        await _expireSession();

        return _handleResponse(response);
      }

      final repeatedResponse = await request();

      if (repeatedResponse.statusCode == 401) {
        await _expireSession();
      }

      return _handleResponse(repeatedResponse);
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException(
        message:
            'Zahtjev je trajao predugo. Provjerite internet vezu i pokušajte ponovo.',
      );
    } on SocketException {
      throw const AppException(
        message:
            'Nema internet veze. Provjerite mrežnu vezu i pokušajte ponovo.',
      );
    } on http.ClientException {
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

  Future<bool> _refreshAccessToken() async {
    final existingRefresh = _refreshInProgress;

    if (existingRefresh != null) {
      return existingRefresh;
    }

    final refreshFuture = _performTokenRefresh();

    _refreshInProgress = refreshFuture;

    try {
      return await refreshFuture;
    } finally {
      _refreshInProgress = null;
    }
  }

  Future<bool> _performTokenRefresh() async {
    final refreshToken = await sessionStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.trim().isEmpty) {
      return false;
    }

    try {
      final response = await http
          .post(
            _buildUri('/Auth/refresh-token'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken.trim()}),
          )
          .timeout(_requestTimeout);

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

      await sessionStorage.saveTokens(
        accessToken: newAccessToken.trim(),
        refreshToken: newRefreshToken.trim(),
      );

      return true;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on FormatException {
      return false;
    } on http.ClientException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _expireSession() async {
    await sessionStorage.clearSession();

    AppNavigation.goToLogin();
  }

  Uri _buildUri(String endpoint) {
    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '/$endpoint';

    return Uri.parse('${ApiConstants.apiBaseUrl}$normalizedEndpoint');
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
