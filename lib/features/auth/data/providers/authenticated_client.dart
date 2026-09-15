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
  }) : sessionStorage =
           sessionStorage ?? SecureSessionStorage(storage: storage),
       authRepository = authRepository ?? AuthRepositoryImpl();

  final http.Client inner;
  final SessionStorage sessionStorage;
  final AuthRepository authRepository;
  Future<bool>? _refreshFuture;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final prepared = await _withAccessToken(request);
    final response = await inner.send(prepared);
    if (response.statusCode != 401) return response;
    if (request is! http.Request) return response;

    final refreshed = await _refreshSession();
    if (!refreshed) return response;
    return inner.send(await _withAccessToken(request));
  }

  Future<bool> _refreshSession() {
    final existingRefresh = _refreshFuture;
    if (existingRefresh != null) return existingRefresh;

    final refresh = _performRefresh();
    _refreshFuture = refresh;
    refresh.then<void>(
      (_) => _clearRefresh(refresh),
      onError: (Object _, StackTrace _) => _clearRefresh(refresh),
    );
    return refresh;
  }

  void _clearRefresh(Future<bool> refresh) {
    if (identical(_refreshFuture, refresh)) _refreshFuture = null;
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await sessionStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final session = await authRepository.refresh(refreshToken);
      await sessionStorage.save(session);
      return true;
    } on Exception {
      try {
        await sessionStorage.clear();
      } on Exception {
        // A failed cleanup must not prevent the original request from failing safely.
      }
      return false;
    }
  }

  Future<http.BaseRequest> _withAccessToken(http.BaseRequest request) async {
    final token = await sessionStorage.readAccessToken();
    if (request is! http.Request) {
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      return request;
    }

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
      ..persistentConnection = request.persistentConnection;
    if (request is http.Request) copy.bodyBytes = request.bodyBytes;
    return copy;
  }
}
