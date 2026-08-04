import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../services/session_storage_service.dart';
import '../constants/api_constants.dart';
import '../error/app_exception.dart';
import 'session_expiration_notifier.dart';

class ApiClient {
  static const Duration _requestTimeout = Duration(seconds: 20);

  final SessionStorageService sessionStorage;

  Future<bool>? _refreshInProgress;

  ApiClient({required this.sessionStorage});

  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) {
    return _executeRequest(
      requiresAuth: requiresAuth,
      request: () async {
        return http
            .get(
              _buildUri(endpoint),
              headers: await _buildHeaders(requiresAuth: requiresAuth),
            )
            .timeout(_requestTimeout);
      },
    );
  }

  Future<dynamic> post(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) {
    return _executeRequest(
      requiresAuth: requiresAuth,
      request: () async {
        return http
            .post(
              _buildUri(endpoint),
              headers: await _buildHeaders(requiresAuth: requiresAuth),
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(_requestTimeout);
      },
    );
  }

  Future<dynamic> postMultipartFile(
    String endpoint, {
    required String filePath,
    String fieldName = 'file',
    bool requiresAuth = true,
  }) {
    return _executeRequest(
      requiresAuth: requiresAuth,
      request: () async {
        final request = http.MultipartRequest('POST', _buildUri(endpoint));

        final headers = await _buildHeaders(requiresAuth: requiresAuth);

        headers.remove('Content-Type');

        request.headers.addAll(headers);

        request.files.add(
          await http.MultipartFile.fromPath(fieldName, filePath),
        );

        final streamedResponse = await request.send().timeout(_requestTimeout);

        return http.Response.fromStream(
          streamedResponse,
        ).timeout(_requestTimeout);
      },
    );
  }

  Future<dynamic> put(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) {
    return _executeRequest(
      requiresAuth: requiresAuth,
      request: () async {
        return http
            .put(
              _buildUri(endpoint),
              headers: await _buildHeaders(requiresAuth: requiresAuth),
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
  }) {
    return _executeRequest(
      requiresAuth: requiresAuth,
      request: () async {
        final request = http.Request('DELETE', _buildUri(endpoint));

        request.headers.addAll(await _buildHeaders(requiresAuth: requiresAuth));

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

  Future<dynamic> _executeRequest({
    required bool requiresAuth,
    required Future<http.Response> Function() request,
  }) async {
    try {
      final response = await request();

      if (!requiresAuth || response.statusCode != 401) {
        return _handleResponse(response);
      }

      final refreshed = await _refreshAccessToken();

      if (!refreshed) {
        await _expireSession();

        throw AppException(
          message: 'Vaša sesija je istekla. Prijavite se ponovo.',
          statusCode: 401,
          title: 'Sesija je istekla',
          isSessionExpired: true,
        );
      }

      final repeatedResponse = await request();

      if (repeatedResponse.statusCode == 401) {
        await _expireSession();

        throw AppException(
          message: 'Vaša sesija je istekla. Prijavite se ponovo.',
          statusCode: 401,
          title: 'Sesija je istekla',
          isSessionExpired: true,
        );
      }

      return _handleResponse(repeatedResponse);
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw AppException(
        message:
            'Zahtjev je trajao predugo. Provjerite internet vezu i pokušajte ponovo.',
        title: 'Zahtjev je istekao',
        isNetworkError: true,
        isTimeout: true,
      );
    } on SocketException {
      throw AppException(
        message:
            'Nije moguće povezati se sa serverom. Provjerite internet vezu i pokušajte ponovo.',
        title: 'Mrežna greška',
        isNetworkError: true,
      );
    } on http.ClientException {
      throw AppException(
        message:
            'Nije moguće povezati se sa serverom. Provjerite internet vezu i pokušajte ponovo.',
        title: 'Mrežna greška',
        isNetworkError: true,
      );
    } catch (_) {
      throw AppException(
        message:
            'Došlo je do neočekivane greške prilikom komunikacije sa serverom.',
        title: 'Greška zahtjeva',
      );
    }
  }

  Future<void> _expireSession() async {
    await sessionStorage.clearSession();

    SessionExpirationNotifier.notifyExpired();
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

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.body.trim().isEmpty) {
        return false;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final accessToken = decoded['token'];

      final newRefreshToken = decoded['refreshToken'];

      final role = decoded['role'];

      if (accessToken is! String || accessToken.trim().isEmpty) {
        return false;
      }

      if (newRefreshToken is! String || newRefreshToken.trim().isEmpty) {
        return false;
      }

      if (role is! String || role.toLowerCase() != 'admin') {
        await sessionStorage.clearSession();

        return false;
      }

      await sessionStorage.saveSession(
        accessToken: accessToken.trim(),
        refreshToken: newRefreshToken.trim(),
        role: role,
      );

      return true;
    } on TimeoutException {
      /*
       * Refresh nije moguć zbog
       * mreže; originalni request
       * tretiramo kao neuspješan refresh.
       */
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

  Future<Map<String, String>> _buildHeaders({
    required bool requiresAuth,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (!requiresAuth) {
      return headers;
    }

    final token = await sessionStorage.getAccessToken();

    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    return headers;
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

    throw _createAppException(response);
  }

  AppException _createAppException(http.Response response) {
    if (response.body.trim().isEmpty) {
      final message = _defaultMessageForStatus(response.statusCode);

      return AppException(
        message: message,
        statusCode: response.statusCode,
        isSessionExpired: response.statusCode == 401,
      );
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);

        final title = _readString(data['title']);

        final detail = _readString(data['detail']);

        final message = _readString(data['message']);

        final validationErrors = _extractValidationErrors(
          data['validationErrors'] ?? data['errors'],
        );

        return AppException(
          message: _resolveMessage(
            statusCode: response.statusCode,
            title: title,
            detail: detail,
            message: message,
            validationErrors: validationErrors,
          ),
          statusCode: response.statusCode,
          title: title,
          detail: detail,
          validationErrors: validationErrors,
          isSessionExpired: response.statusCode == 401,
        );
      }

      if (decoded is String && decoded.trim().isNotEmpty) {
        return AppException(
          message: decoded.trim(),
          statusCode: response.statusCode,
          isSessionExpired: response.statusCode == 401,
        );
      }
    } on FormatException {
      /*
       * Ne prikazujemo HTML,
       * server dump ili raw response
       * klijentu kao korisničku poruku.
       */
      return AppException(
        message: _defaultMessageForStatus(response.statusCode),
        statusCode: response.statusCode,
        isSessionExpired: response.statusCode == 401,
      );
    }

    return AppException(
      message: _defaultMessageForStatus(response.statusCode),
      statusCode: response.statusCode,
      isSessionExpired: response.statusCode == 401,
    );
  }

  Map<String, List<String>> _extractValidationErrors(dynamic rawErrors) {
    if (rawErrors is! Map) {
      return const {};
    }

    final result = <String, List<String>>{};

    for (final entry in rawErrors.entries) {
      final key = entry.key.toString();

      final value = entry.value;

      final messages = <String>[];

      if (value is List) {
        for (final item in value) {
          final text = item?.toString().trim();

          if (text != null && text.isNotEmpty) {
            messages.add(text);
          }
        }
      } else if (value != null) {
        final text = value.toString().trim();

        if (text.isNotEmpty) {
          messages.add(text);
        }
      }

      if (messages.isNotEmpty) {
        result[key] = messages;
      }
    }

    return result;
  }

  String _resolveMessage({
    required int statusCode,
    String? title,
    String? detail,
    String? message,
    required Map<String, List<String>> validationErrors,
  }) {
    if (validationErrors.isNotEmpty) {
      return validationErrors.values.expand((messages) => messages).join('\n');
    }

    if (detail != null && detail.isNotEmpty && !_isGenericDetail(detail)) {
      return detail;
    }

    if (message != null && message.isNotEmpty) {
      return message;
    }

    if (title != null &&
        title.isNotEmpty &&
        title.toLowerCase() != 'validation failed') {
      return title;
    }

    return _defaultMessageForStatus(statusCode);
  }

  bool _isGenericDetail(String value) {
    final normalized = value.toLowerCase();

    return normalized == 'one or more validation errors occurred.' ||
        normalized == 'an unexpected server error occurred.';
  }

  String _defaultMessageForStatus(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Podaci zahtjeva nisu ispravni.';

      case 401:
        return 'Vaša sesija je istekla. Prijavite se ponovo.';

      case 403:
        return 'Nemate dozvolu za ovu akciju.';

      case 404:
        return 'Traženi podatak nije pronađen.';

      case 409:
        return 'Akcija nije moguća zbog postojećih podataka ili poslovnog pravila.';

      case 500:
        return 'Došlo je do greške na serveru.';

      case 502:
      case 503:
      case 504:
        return 'Server trenutno nije dostupan. Pokušajte ponovo.';

      default:
        return 'Zahtjev nije mogao biti izvršen.';
    }
  }

  String? _readString(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }
}
