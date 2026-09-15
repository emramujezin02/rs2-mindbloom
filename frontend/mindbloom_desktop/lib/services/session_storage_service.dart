import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorageService {
  static const String _accessTokenKey = 'mindbloom_desktop_access_token';

  static const String _refreshTokenKey = 'mindbloom_desktop_refresh_token';

  static const String _roleKey = 'mindbloom_desktop_role';

  final FlutterSecureStorage _storage;

  SessionStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String role,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _roleKey, value: role);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> getToken() {
    return getAccessToken();
  }

  Future<String?> getRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<String?> getRole() {
    return _storage.read(key: _roleKey);
  }

  Future<bool> hasAdminSession() async {
    final accessToken = await getAccessToken();

    final refreshToken = await getRefreshToken();

    final role = await getRole();

    return accessToken != null &&
        accessToken.trim().isNotEmpty &&
        refreshToken != null &&
        refreshToken.trim().isNotEmpty &&
        role != null &&
        role.toLowerCase() == 'admin';
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _roleKey);
  }

  Future<void> clear() {
    return clearSession();
  }
}
