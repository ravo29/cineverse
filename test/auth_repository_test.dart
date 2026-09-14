import 'package:flutter_test/flutter_test.dart';

import 'package:cineverse/features/auth/data/providers/auth_provider.dart';
import 'package:cineverse/features/auth/data/repositories/auth_repository.dart';

class _FakeAuthProvider implements AuthProvider {
  @override
  Future<AuthSession> login({required String email, required String password}) {
    return Future.value(const AuthSession(accessToken: 'access'));
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {}

  @override
  Future<AuthSession> refresh(String refreshToken) {
    return Future.value(const AuthSession(accessToken: 'refreshed'));
  }
}

void main() {
  test('repository exposes the auth session from login', () async {
    final repository = AuthRepositoryImpl(provider: _FakeAuthProvider());

    final session = await repository.login(email: 'a@b.test', password: 'pass');

    expect(session.accessToken, 'access');
  });

  test('repository forwards registration to the provider', () async {
    final repository = AuthRepositoryImpl(provider: _FakeAuthProvider());

    await expectLater(
      repository.register(name: 'Ada', email: 'a@b.test', password: 'pass'),
      completes,
    );
  });
}