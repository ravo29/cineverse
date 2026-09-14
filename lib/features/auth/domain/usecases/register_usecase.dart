import '../../data/repositories/auth_repository.dart';
import 'login_usecase.dart';

class RegisterUseCase {
  RegisterUseCase({required this.repository, required this._loginUseCase});

  final AuthRepository repository;
  final LoginUseCase _loginUseCase;

  Future<void> call({
    required String name,
    required String email,
    required String password,
  }) async {
    await repository.register(name: name, email: email, password: password);
    await _loginUseCase(email: email, password: password);
  }
}
