import '../providers/auth_provider.dart';

abstract interface class AuthRepository {
  Future<AuthSession> login({required String email, required String password});

  Future<void> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthSession> refresh(String refreshToken);

  Future<void> logout(String accessToken);
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({AuthProvider? provider})
    : _provider = provider ?? RestAuthProvider();

  final AuthProvider _provider;

  @override
  Future<AuthSession> login({required String email, required String password}) {
    return _provider.login(email: email, password: password);
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _provider.register(name: name, email: email, password: password);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) {
    return _provider.refresh(refreshToken);
  }

  @override
  Future<void> logout(String accessToken) {
    return _provider.logout(accessToken);
  }
}
