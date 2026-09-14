import '../../data/providers/favorites_provider.dart';
import '../entities/movie.dart';

class ToggleFavoriteUseCase {
  ToggleFavoriteUseCase({required this._provider});

  final FavoritesProvider _provider;

  Future<bool> isFavorite(String movieId) => _provider.isFavorite(movieId);

  Future<FavoritesLoadResult> getFavorites() => _provider.getFavorites();

  Future<FavoriteSyncResult> call(Movie movie) => _provider.toggle(movie);

  Future<FavoriteSyncResult> remove(Movie movie) => _provider.remove(movie);

  Future<void> synchronizePending() => _provider.synchronizePending();
}
