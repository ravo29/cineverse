import '../../data/providers/auth_provider.dart';
import '../../data/repositories/auth_repository.dart';

class LoginUseCase {
  LoginUseCase({required this.repository, required this._tokenProvider});

  final AuthRepository repository;
  final SecureTokenProvider _tokenProvider;

  Future<void> call({required String email, required String password}) async {
    final session = await repository.login(
      email: email,
      password: password,
    );
    await _tokenProvider.saveSession(session);
  }
}
