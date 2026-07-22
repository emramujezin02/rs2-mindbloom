import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorageService {
  static const String _accessTokenKey = 'mindbloom_access_token';

  static const String _refreshTokenKey = 'mindbloom_refresh_token';

  final FlutterSecureStorage _storage;

  static const String _userRoleKey = 'mindbloom_user_role';

  SessionStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([saveToken(accessToken), saveRefreshToken(refreshToken)]);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<String?> readToken() async {
    return getToken();
  }

  Future<String?> readRefreshToken() async {
    return getRefreshToken();
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<void> clearSession() async {
    await Future.wait([deleteToken(), deleteRefreshToken(), deleteUserRole()]);
  }

  Future<void> clear() async {
    await clearSession();
  }

  Future<void> saveUserRole(String role) async {
    await _storage.write(key: _userRoleKey, value: role);
  }

  Future<String?> getUserRole() async {
    return _storage.read(key: _userRoleKey);
  }

  Future<void> deleteUserRole() async {
    await _storage.delete(key: _userRoleKey);
  }
}
