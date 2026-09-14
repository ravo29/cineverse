import 'package:flutter_test/flutter_test.dart';

import 'package:cineverse/features/home/data/providers/movies_provider.dart';
import 'package:cineverse/features/home/data/repositories/movies_repository.dart';
import 'package:cineverse/features/home/domain/entities/movie.dart';

class _FakeMoviesProvider implements MoviesProvider {
  _FakeMoviesProvider(this.movie);

  final Movie movie;

  @override
  Future<MoviesPage> fetchPopular({required int page, required int pageSize}) {
    return Future.value(MoviesPage(movies: [movie], hasMore: false));
  }

  @override
  Future<Movie> fetchDetails({required String movieId}) {
    return Future.value(movie);
  }
}

void main() {
  final movie = Movie(id: '1', title: 'Arrival');

  test('returns the popular page from the data source', () async {
    final repository = MoviesRepositoryImpl(
      provider: _FakeMoviesProvider(movie),
    );

    final result = await repository.getPopular(page: 1, pageSize: 20);

    expect(result.movies.single.title, 'Arrival');
    expect(result.hasMore, isFalse);
  });

  test('returns details for the requested movie', () async {
    final repository = MoviesRepositoryImpl(
      provider: _FakeMoviesProvider(movie),
    );

    final result = await repository.getDetails(movieId: '1');

    expect(result.id, '1');
  });

  test('keeps the cache metadata exposed to the domain layer', () async {
    final cachedProvider = _CachedMoviesProvider(movie);
    final repository = MoviesRepositoryImpl(provider: cachedProvider);

    final result = await repository.getPopular(page: 1, pageSize: 20);

    expect(result.fromCache, isTrue);
  });
}

class _CachedMoviesProvider extends _FakeMoviesProvider {
  _CachedMoviesProvider(super.movie);

  @override
  Future<MoviesPage> fetchPopular({required int page, required int pageSize}) {
    return Future.value(
      MoviesPage(movies: [movie], hasMore: false, fromCache: true),
    );
  }
}