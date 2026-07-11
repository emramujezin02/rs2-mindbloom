import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/session_storage_service.dart';
import '../constants/api_constants.dart';
import '../error/app_exception.dart';

class ApiClient {
  final SessionStorageService sessionStorage;

  ApiClient({required this.sessionStorage});

  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    final response = await http.get(
      _buildUri(endpoint),
      headers: await _headers(requiresAuth: requiresAuth),
    );

    return _handleResponse(response);
  }

  Future<dynamic> post(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    final response = await http.post(
      _buildUri(endpoint),
      headers: await _headers(requiresAuth: requiresAuth),
      body: body == null ? null : jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> put(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    final response = await http.put(
      _buildUri(endpoint),
      headers: await _headers(requiresAuth: requiresAuth),
      body: body == null ? null : jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> delete(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    final request = http.Request('DELETE', _buildUri(endpoint));

    request.headers.addAll(await _headers(requiresAuth: requiresAuth));

    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(streamedResponse);

    return _handleResponse(response);
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
      return 'Request failed with status '
          '${response.statusCode}.';
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
