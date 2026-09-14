import '../../data/repositories/movies_repository.dart';
import '../entities/movie.dart';

class GetMovieDetailsUseCase {
    GetMovieDetailsUseCase({required this.repository});

    final MoviesRepository repository;

  Future<Movie> call({required String movieId}) {
    return repository.getDetails(movieId: movieId);
  }
}
