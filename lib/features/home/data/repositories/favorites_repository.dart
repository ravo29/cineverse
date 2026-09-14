import '../providers/favorites_provider.dart';
import '../../domain/entities/movie.dart';

abstract interface class FavoritesRepository {
  Future<bool> isFavorite(String movieId);

  Future<FavoritesLoadResult> getFavorites();

  Future<FavoriteSyncResult> toggle(Movie movie);

  Future<FavoriteSyncResult> remove(Movie movie);

  Future<void> synchronizePending();
}

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl({FavoritesProvider? provider})
      : _provider = provider ?? FavoritesProvider();

  final FavoritesProvider _provider;

  @override
  Future<bool> isFavorite(String movieId) => _provider.isFavorite(movieId);

  @override
  Future<FavoritesLoadResult> getFavorites() => _provider.getFavorites();

  @override
  Future<FavoriteSyncResult> toggle(Movie movie) => _provider.toggle(movie);

  @override
  Future<FavoriteSyncResult> remove(Movie movie) => _provider.remove(movie);

  @override
  Future<void> synchronizePending() => _provider.synchronizePending();
}