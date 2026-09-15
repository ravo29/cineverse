import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cineverse/features/auth/data/providers/authenticated_client.dart';
import 'package:cineverse/features/auth/data/providers/auth_provider.dart';
import 'package:cineverse/features/auth/data/repositories/auth_repository.dart';
import 'package:cineverse/features/auth/data/storage/session_storage.dart';

class _FakeSessionStorage implements SessionStorage {
  String? accessToken = 'expired';
  String? refreshToken = 'refresh';

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> save(AuthSession session) async {
    accessToken = session.accessToken;
    refreshToken = session.refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}

class _FakeAuthRepository implements AuthRepository {
  int refreshCalls = 0;

  @override
  Future<AuthSession> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    refreshCalls++;
    await Future<void>.delayed(Duration.zero);
    return const AuthSession(accessToken: 'fresh', refreshToken: 'refresh-2');
  }

  @override
  Future<void> logout(String accessToken) async {}
}

class _UnauthorizedOnceClient extends http.BaseClient {
  int calls = 0;
  final List<String?> authorizationHeaders = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    authorizationHeaders.add(request.headers['Authorization']);
    final statusCode = calls <= 2 ? 401 : 200;
    return http.StreamedResponse(
      Stream<Uint8List>.empty(),
      statusCode,
      request: request,
    );
  }
}

void main() {
  test(
    'shares one token refresh between concurrent unauthorized requests',
    () async {
      final storage = _FakeSessionStorage();
      final authRepository = _FakeAuthRepository();
      final inner = _UnauthorizedOnceClient();
      final client = AuthenticatedClient(
        inner: inner,
        authRepository: authRepository,
        sessionStorage: storage,
      );

      final responses = await Future.wait([
        client.get(Uri.parse('https://example.test/one')),
        client.get(Uri.parse('https://example.test/two')),
      ]);

      expect(responses.map((response) => response.statusCode), [200, 200]);
      expect(authRepository.refreshCalls, 1);
      expect(storage.accessToken, 'fresh');
      expect(inner.authorizationHeaders, [
        'Bearer expired',
        'Bearer expired',
        'Bearer fresh',
        'Bearer fresh',
      ]);
    },
  );
}
