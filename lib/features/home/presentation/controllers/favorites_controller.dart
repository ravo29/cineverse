import 'package:flutter/foundation.dart';

import '../../data/providers/favorites_provider.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../domain/entities/movie.dart';
import '../../domain/usecases/toggle_favorite_usecase.dart';

class FavoritesController extends ChangeNotifier {
  FavoritesController({FavoritesRepository? repository})
    : _useCase = ToggleFavoriteUseCase(
        repository: repository ?? FavoritesRepositoryImpl(),
      );

  final ToggleFavoriteUseCase _useCase;
  List<Movie> _favorites = const [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _fromCache = false;
  int _pendingOperations = 0;

  List<Movie> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get fromCache => _fromCache;
  int get pendingOperations => _pendingOperations;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _useCase.getFavorites();
      _favorites = List.unmodifiable(result.favorites);
      _fromCache = result.fromCache;
    } on Exception {
      _errorMessage = 'Impossible de charger les favoris.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<FavoriteSyncResult?> remove(Movie movie) async {
    _favorites = List.unmodifiable(
      _favorites.where((item) => item.id != movie.id),
    );
    notifyListeners();

    try {
      final result = await _useCase.remove(movie);
      _pendingOperations = result.pendingOperations;
      notifyListeners();
      return result;
    } on Exception {
      _errorMessage = 'Impossible de modifier les favoris.';
      notifyListeners();
      return null;
    }
  }
}
