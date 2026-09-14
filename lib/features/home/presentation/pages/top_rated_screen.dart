import 'package:flutter/material.dart';

import '../../data/providers/movies_provider.dart';
import '../../data/repositories/movies_repository.dart';
import '../../domain/entities/movie.dart';
import '../../domain/usecases/get_top_rated_movies_usecase.dart';
import 'movie_detail_screen.dart';

class TopRatedScreen extends StatefulWidget {
  const TopRatedScreen({super.key});

  @override
  State<TopRatedScreen> createState() => _TopRatedScreenState();
}

class _TopRatedScreenState extends State<TopRatedScreen> {
  late final Future<List<Movie>> _movies = _loadMovies();

  Future<List<Movie>> _loadMovies() async {
    final page = await GetTopRatedMoviesUseCase(
      repository: MoviesRepositoryImpl(),
    )(page: 1, pageSize: 20);
    return page.movies;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Films les mieux notés')),
      body: FutureBuilder<List<Movie>>(
        future: _movies,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error is MoviesException
                    ? (snapshot.error! as MoviesException).message
                    : 'Impossible de charger les films les mieux notés.',
                textAlign: TextAlign.center,
              ),
            );
          }
          final movies = snapshot.data ?? const <Movie>[];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return ListTile(
                title: Text(movie.title),
                subtitle: Text(movie.rating?.toStringAsFixed(1) ?? 'N/A'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MovieDetailScreen(movieId: movie.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}