import '../../data/providers/auth_provider.dart';

class LoginUseCase {
  LoginUseCase({required this._authProvider, required this._tokenProvider});

  final AuthProvider _authProvider;
  final SecureTokenProvider _tokenProvider;

  Future<void> call({required String email, required String password}) async {
    final session = await _authProvider.login(
      email: email,
      password: password,
    );
    await _tokenProvider.saveSession(session);
  }
}
