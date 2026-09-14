import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../../core/errors/auth_exception.dart';

abstract interface class AuthProvider {
  Future<String> login({required String email, required String password});

  Future<void> register({
    required String name,
    required String email,
    required String password,
  });
}

class RestAuthProvider implements AuthProvider {
  RestAuthProvider({http.Client? client}) : _client = client ?? http.Client();

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _requestTimeout = Duration(seconds: 15);

  final http.Client _client;

  @override
  Future<String> login({
    required String email,
    required String password,
  }) async {
    if (!_isConfigured) {
      throw const AuthException(
        'Configuration Supabase absente. Lancez avec SUPABASE_URL et SUPABASE_ANON_KEY.',
      );
    }

    try {
      final endpoint = Uri.parse(
        '$_baseUrl/auth/v1/token',
      ).replace(queryParameters: {'grant_type': 'password'});
      final response = await _post(
        endpoint,
        body: {'email': email, 'password': password},
      );

      final responseBody = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(_errorMessage(response.statusCode, responseBody));
      }

      final accessToken = responseBody['access_token'];
      if (accessToken is! String || accessToken.isEmpty) {
        throw const AuthException('Le serveur n’a pas renvoyé de token JWT.');
      }

      return accessToken;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(
        'Connexion réseau impossible. Le serveur met trop de temps à répondre.',
      );
    } on http.ClientException {
      throw const AuthException('Connexion réseau impossible.');
    } on FormatException {
      throw const AuthException('Réponse invalide du serveur.');
    } on Exception {
      throw const AuthException('Connexion réseau impossible.');
    }
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!_isConfigured) {
      throw const AuthException(
        'Configuration Supabase absente. Lancez avec SUPABASE_URL et SUPABASE_ANON_KEY.',
      );
    }

    try {
      final endpoint = Uri.parse('$_baseUrl/auth/v1/signup');
      final response = await _post(
        endpoint,
        body: {
          'email': email,
          'password': password,
          'data': {'name': name},
        },
      );
      final responseBody = _decodeResponse(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          _registrationError(response.statusCode, responseBody),
        );
      }
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(
        'Connexion réseau impossible. Le serveur met trop de temps à répondre.',
      );
    } on http.ClientException {
      throw const AuthException('Connexion réseau impossible.');
    } on FormatException {
      throw const AuthException('Réponse invalide du serveur.');
    } on Exception {
      throw const AuthException('Connexion réseau impossible.');
    }
  }

  Future<http.Response> _post(
    Uri endpoint, {
    required Map<String, dynamic> body,
  }) {
    return _client
        .post(
          endpoint,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'apikey': _supabaseAnonKey,
          },
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
  }

  bool get _isConfigured =>
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  String get _baseUrl => _supabaseUrl.replaceFirst(RegExp(r'\/$'), '');

  Map<String, dynamic> _decodeResponse(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }

    return decoded;
  }

  String _errorMessage(int statusCode, Map<String, dynamic> responseBody) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Identifiants incorrects.';
    }
    if (statusCode >= 500) {
      return 'Serveur indisponible. Réessayez plus tard.';
    }

    final message = responseBody['message'] ?? responseBody['error'];
    if (message is String && message.isNotEmpty) {
      return message;
    }

    return 'Identifiants invalides.';
  }

  String _registrationError(int statusCode, Map<String, dynamic> responseBody) {
    if (statusCode == 409) return 'Cette adresse e-mail est déjà utilisée.';
    if (statusCode >= 500) return 'Serveur indisponible. Réessayez plus tard.';

    final message = responseBody['msg'] ??
        responseBody['message'] ??
        responseBody['error_description'] ??
        responseBody['error'];
    if (message is String && message.isNotEmpty) return message;
    if (statusCode == 422) {
      return 'Inscription refusée par Supabase. Vérifiez votre e-mail et votre mot de passe.';
    }
    return 'Inscription impossible.';
  }
}

class SecureTokenProvider {
  SecureTokenProvider({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const tokenKey = 'access_token';
  final FlutterSecureStorage _storage;

  Future<void> save(String token) async {
    try {
      await _storage.write(key: tokenKey, value: token);
    } on Exception {
      throw const AuthException(
        'Impossible de sécuriser la session. Veuillez réessayer.',
      );
    }
  }

  Future<String?> read() async {
    try {
      return await _storage.read(key: tokenKey);
    } on Exception {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: tokenKey);
    } on Exception {
      throw const AuthException(
        'Impossible de fermer la session de manière sécurisée.',
      );
    }
  }
}
