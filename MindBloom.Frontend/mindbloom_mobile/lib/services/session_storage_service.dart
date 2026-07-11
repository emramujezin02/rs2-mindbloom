import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorageService {
  static const String _accessTokenKey = 'mindbloom_access_token';

  static const String _refreshTokenKey = 'mindbloom_refresh_token';

  final FlutterSecureStorage _storage;

  SessionStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
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
    await Future.wait([deleteToken(), deleteRefreshToken()]);
  }

  Future<void> clear() async {
    await clearSession();
  }
}
