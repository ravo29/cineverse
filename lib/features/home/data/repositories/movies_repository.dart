import '../providers/movies_provider.dart';
import '../../domain/entities/movie.dart';

abstract interface class MoviesRepository {
  Future<MoviesPage> getPopular({required int page, required int pageSize});

  Future<MoviesPage> getTopRated({required int page, required int pageSize});

  Future<Movie> getDetails({required String movieId});
}

class MoviesRepositoryImpl implements MoviesRepository {
  MoviesRepositoryImpl({MoviesProvider? provider})
      : _provider = provider ?? RestMoviesProvider();

  final MoviesProvider _provider;

  @override
  Future<MoviesPage> getPopular({required int page, required int pageSize}) {
    return _provider.fetchPopular(page: page, pageSize: pageSize);
  }

  @override
  Future<MoviesPage> getTopRated({required int page, required int pageSize}) {
    return _provider.fetchTopRated(page: page, pageSize: pageSize);
  }

  @override
  Future<Movie> getDetails({required String movieId}) {
    return _provider.fetchDetails(movieId: movieId);
  }
}