import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/movie.dart';

class MoviesException implements Exception {
  const MoviesException(this.message);

  final String message;
}

class MoviesPage {
  const MoviesPage({
    required this.movies,
    required this.hasMore,
    this.fromCache = false,
  });

  final List<Movie> movies;
  final bool hasMore;
  final bool fromCache;
}

abstract interface class MoviesProvider {
  Future<MoviesPage> fetchPopular({required int page, required int pageSize});

  Future<Movie> fetchDetails({required String movieId});
}

class RestMoviesProvider implements MoviesProvider {
  RestMoviesProvider({http.Client? client}) : _client = client ?? http.Client();

  static const _tmdbApiKey = String.fromEnvironment('TMDB_API_KEY');
  static const _tmdbBearerToken = String.fromEnvironment('TMDB_BEARER_TOKEN');
  static const _tmdbEndpoint = 'https://api.themoviedb.org/3/movie/popular';
  static const _posterBaseUrl = 'https://image.tmdb.org/t/p/w500';
  static const _requestTimeout = Duration(seconds: 15);
  static const _cacheBoxName = 'cineverse';

  final http.Client _client;

  @override
  Future<MoviesPage> fetchPopular({
    required int page,
    required int pageSize,
  }) async {
    try {
      final remotePage = await _fetchRemote(page);
      await _saveToCache(page, remotePage);
      return remotePage;
    } on Exception catch (error) {
      final cachedPage = await _readFromCache(page);
      if (cachedPage != null) return cachedPage;
      if (error is MoviesException) rethrow;
      throw const MoviesException('Impossible de charger les films.');
    }
  }

  @override
  Future<Movie> fetchDetails({required String movieId}) async {
    if (_tmdbApiKey.isEmpty && _tmdbBearerToken.isEmpty) {
      throw const MoviesException(
        'Clé API TMDB non configurée. Utilisez TMDB_API_KEY.',
      );
    }

    try {
      final queryParameters = <String, String>{'language': 'fr-FR'};
      if (_tmdbBearerToken.isEmpty) queryParameters['api_key'] = _tmdbApiKey;
      final endpoint = Uri.parse(
        'https://api.themoviedb.org/3/movie/$movieId',
      ).replace(queryParameters: queryParameters);
      final response = await _client
          .get(
            endpoint,
            headers: {
              'Accept': 'application/json',
              if (_tmdbBearerToken.isNotEmpty)
                'Authorization': 'Bearer $_tmdbBearerToken',
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MoviesException(_errorMessage(response.statusCode));
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid TMDB movie response');
      }
      return Movie.fromJson(_withHighDefinitionPoster(decoded));
    } on MoviesException {
      rethrow;
    } on TimeoutException {
      throw const MoviesException('Connexion réseau impossible.');
    } on http.ClientException {
      throw const MoviesException('Impossible de charger le film.');
    } on FormatException {
      throw const MoviesException('Réponse invalide du serveur.');
    } on Exception {
      throw const MoviesException('Impossible de charger le film.');
    }
  }

  Future<MoviesPage> _fetchRemote(int page) async {
    if (_tmdbApiKey.isEmpty && _tmdbBearerToken.isEmpty) {
      throw const MoviesException(
        'Clé API TMDB non configurée. Utilisez TMDB_API_KEY.',
      );
    }

    try {
      final queryParameters = <String, String>{
        'language': 'fr-FR',
        'page': '$page',
      };
      if (_tmdbBearerToken.isEmpty) {
        queryParameters['api_key'] = _tmdbApiKey;
      }
      final endpoint = Uri.parse(
        _tmdbEndpoint,
      ).replace(queryParameters: queryParameters);
      final response = await _client
          .get(
            endpoint,
            headers: {
              'Accept': 'application/json',
              if (_tmdbBearerToken.isNotEmpty)
                'Authorization': 'Bearer $_tmdbBearerToken',
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MoviesException(_errorMessage(response.statusCode));
      }

      return _parsePage(response.body);
    } on MoviesException {
      rethrow;
    } on TimeoutException {
      throw const MoviesException(
        'Connexion réseau impossible. Le serveur met trop de temps à répondre.',
      );
    } on http.ClientException {
      throw const MoviesException('Impossible de charger les films.');
    } on FormatException {
      throw const MoviesException('Réponse invalide du serveur.');
    } on Exception {
      throw const MoviesException('Impossible de charger les films.');
    }
  }

  Future<void> _saveToCache(int page, MoviesPage moviesPage) async {
    try {
      final box = Hive.isBoxOpen(_cacheBoxName)
          ? Hive.box<dynamic>(_cacheBoxName)
          : await Hive.openBox<dynamic>(_cacheBoxName);
      await box.put(_cacheKey(page), {
        'movies': moviesPage.movies.map((movie) => movie.toJson()).toList(),
        'has_more': moviesPage.hasMore,
      });
    } on Exception {
      // A cache failure must not make a successful network response fail.
    }
  }

  Future<MoviesPage?> _readFromCache(int page) async {
    try {
      final box = Hive.isBoxOpen(_cacheBoxName)
          ? Hive.box<dynamic>(_cacheBoxName)
          : await Hive.openBox<dynamic>(_cacheBoxName);
      final cached = box.get(_cacheKey(page));
      if (cached is! Map) return null;

      final rawMovies = cached['movies'];
      if (rawMovies is! List) return null;
      final movies = rawMovies
          .whereType<Map>()
          .map((movie) => Movie.fromJson(Map<String, dynamic>.from(movie)))
          .toList(growable: false);
      final hasMore = cached['has_more'];
      return MoviesPage(
        movies: movies,
        hasMore: hasMore is bool ? hasMore : false,
        fromCache: true,
      );
    } on Exception {
      return null;
    }
  }

  String _cacheKey(int page) => 'popular_movies_page_$page';

  MoviesPage _parsePage(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid TMDB response');
    }

    final rawMovies = decoded['results'];

    if (rawMovies is! List) {
      throw const FormatException('Invalid TMDB results');
    }

    final movies = rawMovies
        .whereType<Map<String, dynamic>>()
        .map(_withPosterUrl)
        .map(Movie.fromJson)
        .toList(growable: false);
    final currentPage = decoded['page'];
    final totalPages = decoded['total_pages'];

    return MoviesPage(
      movies: movies,
      hasMore: currentPage is num && totalPages is num
          ? currentPage < totalPages
          : movies.isNotEmpty,
    );
  }

  Map<String, dynamic> _withPosterUrl(Map<String, dynamic> movie) {
    final posterPath = movie['poster_path'];
    if (posterPath is! String || posterPath.isEmpty) return movie;

    return {...movie, 'poster_url': '$_posterBaseUrl$posterPath'};
  }

  Map<String, dynamic> _withHighDefinitionPoster(Map<String, dynamic> movie) {
    final posterPath = movie['poster_path'];
    if (posterPath is! String || posterPath.isEmpty) return movie;
    return {
      ...movie,
      'poster_url': 'https://image.tmdb.org/t/p/w1280$posterPath',
    };
  }

  String _errorMessage(int statusCode) {
    if (statusCode == 401 || statusCode == 403) return 'Clé API TMDB invalide.';
    if (statusCode == 429) return 'Limite TMDB atteinte. Réessayez plus tard.';
    if (statusCode >= 500) return 'Serveur indisponible. Réessayez plus tard.';
    return 'Impossible de charger les films.';
  }
}
