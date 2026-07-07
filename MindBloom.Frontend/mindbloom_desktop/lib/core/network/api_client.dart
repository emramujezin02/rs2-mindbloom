import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../error/app_exception.dart';

class ApiClient {
  Future<dynamic> get(String endpoint, {String? token}) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.apiBaseUrl}$endpoint'),
      headers: _headers(token),
    );

    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, {Object? body, String? token}) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.apiBaseUrl}$endpoint'),
      headers: _headers(token),
      body: body == null ? null : jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, {Object? body, String? token}) async {
    final response = await http.put(
      Uri.parse('${ApiConstants.apiBaseUrl}$endpoint'),
      headers: _headers(token),
      body: body == null ? null : jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint, {String? token}) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.apiBaseUrl}$endpoint'),
      headers: _headers(token),
    );

    return _handleResponse(response);
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }

      return jsonDecode(response.body);
    }

    throw AppException(
      message: response.body.isNotEmpty ? response.body : 'Request failed.',
      statusCode: response.statusCode,
    );
  }
}
