import '../../data/providers/movies_provider.dart';

class GetPopularMoviesUseCase {
  GetPopularMoviesUseCase({required this._provider});

  final MoviesProvider _provider;

  Future<MoviesPage> call({required int page, required int pageSize}) {
    return _provider.fetchPopular(page: page, pageSize: pageSize);
  }
}
