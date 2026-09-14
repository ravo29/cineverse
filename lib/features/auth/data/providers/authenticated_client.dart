import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'auth_provider.dart';

typedef SessionRefresher = Future<AuthSession> Function(String refreshToken);

class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient({
    required this.inner,
    required this.storage,
    required this.refresh,
  });

  final http.Client inner;
  final FlutterSecureStorage storage;
  final SessionRefresher refresh;
  bool _refreshing = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final prepared = await _withAccessToken(request);
    final response = await inner.send(prepared);
    if (response.statusCode != 401 || _refreshing) return response;

    final refreshToken = await storage.read(key: SecureTokenProvider.refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return response;

    _refreshing = true;
    try {
      final session = await refresh(refreshToken);
      await storage.write(
        key: SecureTokenProvider.tokenKey,
        value: session.accessToken,
      );
      if (session.refreshToken != null) {
        await storage.write(
          key: SecureTokenProvider.refreshTokenKey,
          value: session.refreshToken,
        );
      }
      return await inner.send(await _withAccessToken(request));
    } finally {
      _refreshing = false;
    }
  }

  Future<http.BaseRequest> _withAccessToken(http.BaseRequest request) async {
    final token = await storage.read(key: SecureTokenProvider.tokenKey);
    final copy = _copyRequest(request);
    if (token != null && token.isNotEmpty) {
      copy.headers['Authorization'] = 'Bearer $token';
    }
    return copy;
  }

  http.Request _copyRequest(http.BaseRequest request) {
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection
      ..contentLength = request.contentLength;
    if (request is http.Request) copy.bodyBytes = request.bodyBytes;
    return copy;
  }
}