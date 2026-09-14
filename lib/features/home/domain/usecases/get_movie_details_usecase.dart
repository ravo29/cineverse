import '../../data/providers/movies_provider.dart';
import '../entities/movie.dart';

class GetMovieDetailsUseCase {
  GetMovieDetailsUseCase({required this._provider});

  final MoviesProvider _provider;

  Future<Movie> call({required String movieId}) {
    return _provider.fetchDetails(movieId: movieId);
  }
}
