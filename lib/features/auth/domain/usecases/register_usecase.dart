import '../../data/providers/auth_provider.dart';
import 'login_usecase.dart';

class RegisterUseCase {
  RegisterUseCase({required this._authProvider, required this._loginUseCase});

  final AuthProvider _authProvider;
  final LoginUseCase _loginUseCase;

  Future<void> call({
    required String name,
    required String email,
    required String password,
  }) async {
    await _authProvider.register(name: name, email: email, password: password);
    await _loginUseCase(email: email, password: password);
  }
}
