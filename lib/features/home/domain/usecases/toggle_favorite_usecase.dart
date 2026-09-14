import '../../data/repositories/favorites_repository.dart';
import '../../data/providers/favorites_provider.dart';
import '../entities/movie.dart';

class ToggleFavoriteUseCase {
  ToggleFavoriteUseCase({required this.repository});

  final FavoritesRepository repository;

  Future<bool> isFavorite(String movieId) => repository.isFavorite(movieId);

  Future<FavoritesLoadResult> getFavorites() => repository.getFavorites();

  Future<FavoriteSyncResult> call(Movie movie) => repository.toggle(movie);

  Future<FavoriteSyncResult> remove(Movie movie) => repository.remove(movie);

  Future<void> synchronizePending() => repository.synchronizePending();
}
