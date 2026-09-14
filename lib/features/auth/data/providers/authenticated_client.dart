import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../repositories/auth_repository.dart';
import '../storage/session_storage.dart';

class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient({
    required this.inner,
    AuthRepository? authRepository,
    SessionStorage? sessionStorage,
    FlutterSecureStorage? storage,
  })  : sessionStorage = sessionStorage ??
            SecureSessionStorage(storage: storage),
        authRepository = authRepository ?? AuthRepositoryImpl();

  final http.Client inner;
  final SessionStorage sessionStorage;
  final AuthRepository authRepository;
  bool _refreshing = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final prepared = await _withAccessToken(request);
    final response = await inner.send(prepared);
    if (response.statusCode != 401 || _refreshing) return response;

    final refreshToken = await sessionStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return response;

    _refreshing = true;
    try {
      final session = await authRepository.refresh(refreshToken);
      await sessionStorage.save(session);
      return await inner.send(await _withAccessToken(request));
    } finally {
      _refreshing = false;
    }
  }

  Future<http.BaseRequest> _withAccessToken(http.BaseRequest request) async {
    final token = await sessionStorage.readAccessToken();
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