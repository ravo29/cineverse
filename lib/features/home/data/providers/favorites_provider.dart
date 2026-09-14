import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/providers/auth_provider.dart';
import '../../../auth/data/providers/authenticated_client.dart';
import '../../domain/entities/movie.dart';

class FavoriteSyncResult {
  const FavoriteSyncResult({required this.isFavorite, required this.synced});

  final bool isFavorite;
  final bool synced;
}

class FavoritesLoadResult {
  const FavoritesLoadResult({required this.favorites, required this.fromCache});

  final List<Movie> favorites;
  final bool fromCache;
}

class FavoritesProvider {
  FavoritesProvider({
    this.boxName = 'cineverse',
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _client = client ??
           AuthenticatedClient(
             inner: http.Client(),
             storage: secureStorage ?? const FlutterSecureStorage(),
             refresh: (token) => RestAuthProvider().refresh(token),
           );

  static const _favoritesKey = 'favorite_movies';
  static const _syncQueueKey = 'favorite_sync_queue';
  static const _accessTokenKey = 'access_token';
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _requestTimeout = Duration(seconds: 15);

  final String boxName;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  Future<bool> isFavorite(String movieId) async {
    final favorites = await _readFavorites();
    return favorites.any((movie) => movie.id == movieId);
  }

  Future<FavoritesLoadResult> getFavorites() async {
    await synchronizePending();

    try {
      final remoteFavorites = await _fetchRemoteFavorites();
      await _writeFavorites(remoteFavorites);
      return FavoritesLoadResult(favorites: remoteFavorites, fromCache: false);
    } on Exception {
      return FavoritesLoadResult(
        favorites: await _readFavorites(),
        fromCache: true,
      );
    }
  }

  Future<FavoriteSyncResult> toggle(Movie movie) async {
    await synchronizePending();

    final favorites = await _readFavorites();
    final index = favorites.indexWhere((item) => item.id == movie.id);
    final isFavorite = index >= 0;
    if (isFavorite) {
      favorites.removeAt(index);
    } else {
      favorites.add(movie);
    }

    await _writeFavorites(favorites);
    final operation = _SyncOperation(
      movie: movie,
      isFavorite: !isFavorite,
      userId: await _currentUserId(),
    );
    await _enqueue(operation);

    final synced = await _send(operation);
    if (synced) await _removeFromQueue(operation);

    return FavoriteSyncResult(isFavorite: !isFavorite, synced: synced);
  }

  Future<FavoriteSyncResult> remove(Movie movie) async {
    await synchronizePending();
    final favorites = await _readFavorites();
    favorites.removeWhere((item) => item.id == movie.id);
    await _writeFavorites(favorites);

    final operation = _SyncOperation(
      movie: movie,
      isFavorite: false,
      userId: await _currentUserId(),
    );
    await _enqueue(operation);
    final synced = await _send(operation);
    if (synced) await _removeFromQueue(operation);

    return FavoriteSyncResult(isFavorite: false, synced: synced);
  }

  Future<void> synchronizePending() async {
    final queue = await _readQueue();
    for (final operation in queue) {
      if (await _send(operation)) {
        await _removeFromQueue(operation);
      }
    }
  }

  Future<void> clearLocalData() async {
    final box = await _openBox();
    await box.delete(_favoritesKey);
    await box.delete(_syncQueueKey);
  }

  Future<bool> _send(_SyncOperation operation) async {
    if (!_hasSupabaseConfig || operation.userId == null) return false;

    try {
      final token = await _secureStorage.read(key: _accessTokenKey);
      if (token == null || token.isEmpty) return false;
      final baseUri = Uri.parse(
        '${_supabaseUrl.replaceFirst(RegExp(r'\/$'), '')}/rest/v1/favorites',
      );
      final headers = {
        'apikey': _supabaseAnonKey,
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      if (operation.isFavorite) {
        final response = await _client
            .post(
              baseUri,
              headers: {...headers, 'Prefer': 'resolution=merge-duplicates'},
              body: jsonEncode({
                'user_id': operation.userId,
                'movie_id': operation.movie.id,
                'movie_data': operation.movie.toJson(),
              }),
            )
            .timeout(_requestTimeout);
        return response.statusCode >= 200 && response.statusCode < 300;
      }

      final endpoint = baseUri.replace(
        queryParameters: {
          'user_id': 'eq.${operation.userId}',
          'movie_id': 'eq.${operation.movie.id}',
        },
      );
      final response = await _client
          .delete(endpoint, headers: headers)
          .timeout(_requestTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } on Exception {
      return false;
    }
  }

  Future<List<Movie>> _fetchRemoteFavorites() async {
    if (!_hasSupabaseConfig) {
      throw const _FavoritesRemoteException();
    }

    final userId = await _currentUserId();
    if (userId == null) throw const _FavoritesRemoteException();

    final token = await _secureStorage.read(key: _accessTokenKey);
    if (token == null || token.isEmpty) {
      throw const _FavoritesRemoteException();
    }

    final endpoint =
        Uri.parse(
          '${_supabaseUrl.replaceFirst(RegExp(r'\/$'), '')}/rest/v1/favorites',
        ).replace(
          queryParameters: {'select': 'movie_data', 'user_id': 'eq.$userId'},
        );
    final response = await _client
        .get(
          endpoint,
          headers: {
            'apikey': _supabaseAnonKey,
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const _FavoritesRemoteException();
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const _FavoritesRemoteException();

    return decoded
        .whereType<Map>()
        .map((row) => row['movie_data'])
        .whereType<Map>()
        .map((movie) => Movie.fromJson(Map<String, dynamic>.from(movie)))
        .toList(growable: true);
  }

  bool get _hasSupabaseConfig =>
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  Future<String?> _currentUserId() async {
    final token = await _secureStorage.read(key: _accessTokenKey);
    if (token == null) return null;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final userId = payload is Map<String, dynamic> ? payload['sub'] : null;
      return userId is String && userId.isNotEmpty ? userId : null;
    } on FormatException {
      return null;
    }
  }

  Future<List<Movie>> _readFavorites() async {
    final box = await _openBox();
    final stored = box.get(_favoritesKey);
    if (stored is! List) return [];
    return stored
        .whereType<Map>()
        .map((item) => Movie.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: true);
  }

  Future<void> _writeFavorites(List<Movie> favorites) async {
    final box = await _openBox();
    await box.put(
      _favoritesKey,
      favorites.map((item) => item.toJson()).toList(growable: false),
    );
  }

  Future<List<_SyncOperation>> _readQueue() async {
    final box = await _openBox();
    final stored = box.get(_syncQueueKey);
    if (stored is! List) return [];
    return stored
        .whereType<Map>()
        .map(_SyncOperation.fromJson)
        .whereType<_SyncOperation>()
        .toList(growable: true);
  }

  Future<void> _enqueue(_SyncOperation operation) async {
    final queue = await _readQueue();
    queue.removeWhere((item) => item.key == operation.key);
    queue.add(operation);
    await _writeQueue(queue);
  }

  Future<void> _removeFromQueue(_SyncOperation operation) async {
    final queue = await _readQueue();
    queue.removeWhere((item) => item.key == operation.key);
    await _writeQueue(queue);
  }

  Future<void> _writeQueue(List<_SyncOperation> queue) async {
    final box = await _openBox();
    await box.put(_syncQueueKey, queue.map((item) => item.toJson()).toList());
  }

  Future<Box<dynamic>> _openBox() {
    return Hive.isBoxOpen(boxName)
        ? Future.value(Hive.box<dynamic>(boxName))
        : Hive.openBox<dynamic>(boxName);
  }
}

class _FavoritesRemoteException implements Exception {
  const _FavoritesRemoteException();
}

class _SyncOperation {
  const _SyncOperation({
    required this.movie,
    required this.isFavorite,
    required this.userId,
  });

  final Movie movie;
  final bool isFavorite;
  final String? userId;

  String get key => '${userId ?? 'anonymous'}:${movie.id}';

  Map<String, dynamic> toJson() => {
    'movie': movie.toJson(),
    'is_favorite': isFavorite,
    'user_id': userId,
  };

  static _SyncOperation? fromJson(Map item) {
    final movie = item['movie'];
    if (movie is! Map) return null;
    return _SyncOperation(
      movie: Movie.fromJson(Map<String, dynamic>.from(movie)),
      isFavorite: item['is_favorite'] == true,
      userId: item['user_id'] is String ? item['user_id'] as String : null,
    );
  }
}
