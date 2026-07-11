import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/session_storage_service.dart';
import '../constants/api_constants.dart';
import '../error/app_exception.dart';
import '../navigation/app_navigation.dart';

class ApiClient {
  final SessionStorageService sessionStorage;

  Future<bool>? _refreshInProgress;

  ApiClient({required this.sessionStorage});

  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    return _executeRequest(
      requiresAuth: requiresAuth,
      request: () async {
        return http.get(
          _buildUri(endpoint),
          headers: await _headers(requiresAuth: requiresAuth),
        );
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
        return http.post(
          _buildUri(endpoint),
          headers: await _headers(requiresAuth: requiresAuth),
          body: body == null ? null : jsonEncode(body),
        );
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
        return http.put(
          _buildUri(endpoint),
          headers: await _headers(requiresAuth: requiresAuth),
          body: body == null ? null : jsonEncode(body),
        );
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

        final streamedResponse = await request.send();

        return http.Response.fromStream(streamedResponse);
      },
    );
  }

  Future<dynamic> _executeRequest({
    required bool requiresAuth,
    required Future<http.Response> Function() request,
  }) async {
    final response = await request();

    if (response.statusCode != 401 || !requiresAuth) {
      return _handleResponse(response);
    }

    final refreshed = await _refreshAccessToken();

    if (!refreshed) {
      await _expireSession();

      return _handleResponse(response);
    }

    /*
     * Originalni zahtjev se ponavlja tačno jednom.
     * Request callback ponovo kreira headers i čita novi token.
     */
    final repeatedResponse = await request();

    if (repeatedResponse.statusCode == 401) {
      await _expireSession();
    }

    return _handleResponse(repeatedResponse);
  }

  Future<bool> _refreshAccessToken() async {
    /*
     * Ako je više API zahtjeva istovremeno dobilo 401,
     * svi čekaju isti refresh zahtjev.
     */
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
      /*
       * Ovdje namjerno koristimo direktno http.post,
       * a ne ApiClient.post().
       *
       * Time sprječavamo da refresh endpoint
       * izazove novi refresh i beskonačnu petlju.
       */
      final response = await http.post(
        _buildUri('/Auth/refresh-token'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken.trim()}),
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

      await sessionStorage.saveTokens(
        accessToken: newAccessToken.trim(),
        refreshToken: newRefreshToken.trim(),
      );

      return true;
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

    return Uri.parse(
      '${ApiConstants.apiBaseUrl}'
      '$normalizedEndpoint',
    );
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

    throw AppException(
      message: _extractErrorMessage(response),
      statusCode: response.statusCode,
    );
  }

  String _extractErrorMessage(http.Response response) {
    if (response.body.trim().isEmpty) {
      if (response.statusCode == 401) {
        return 'Your session has expired. Please log in again.';
      }

      return 'Request failed with status ${response.statusCode}.';
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];

        if (message is String && message.trim().isNotEmpty) {
          return message;
        }

        final title = decoded['title'];

        if (title is String && title.trim().isNotEmpty) {
          return title;
        }

        final errors = decoded['errors'];

        if (errors is Map) {
          final messages = <String>[];

          for (final value in errors.values) {
            if (value is List) {
              messages.addAll(value.map((item) => item.toString()));
            } else if (value != null) {
              messages.add(value.toString());
            }
          }

          if (messages.isNotEmpty) {
            return messages.join('\n');
          }
        }
      }

      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded;
      }
    } on FormatException {
      return response.body;
    }

    return response.body;
  }
}
