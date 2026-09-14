import '../../data/providers/movies_provider.dart';
import '../../data/repositories/movies_repository.dart';

class GetTopRatedMoviesUseCase {
  GetTopRatedMoviesUseCase({required this.repository});

  final MoviesRepository repository;

  Future<MoviesPage> call({required int page, required int pageSize}) {
    return repository.getTopRated(page: page, pageSize: pageSize);
  }
}