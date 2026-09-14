import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers/auth_provider.dart';

abstract interface class SessionStorage {
  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  Future<void> save(AuthSession session);

  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: accessTokenKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: refreshTokenKey);

  @override
  Future<void> save(AuthSession session) async {
    await _storage.write(key: accessTokenKey, value: session.accessToken);
    if (session.refreshToken != null) {
      await _storage.write(key: refreshTokenKey, value: session.refreshToken);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
  }
}