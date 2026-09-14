import '../../data/providers/movies_provider.dart';
import '../../data/repositories/movies_repository.dart';

class GetPopularMoviesUseCase {
  GetPopularMoviesUseCase({required this.repository});

  final MoviesRepository repository;

  Future<MoviesPage> call({required int page, required int pageSize}) {
    return repository.getPopular(page: page, pageSize: pageSize);
  }
}
