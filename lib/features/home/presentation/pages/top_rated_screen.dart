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
  late Future<MoviesPage> _movies = _loadMovies();

  Future<MoviesPage> _loadMovies() {
    return GetTopRatedMoviesUseCase(
      repository: MoviesRepositoryImpl(),
    )(page: 1, pageSize: 20);
  }

  Future<void> _refresh() async {
    final future = _loadMovies();
    setState(() => _movies = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Films les mieux notés')),
      body: FutureBuilder<MoviesPage>(
        future: _movies,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error is MoviesException
                  ? (snapshot.error! as MoviesException).message
                  : 'Impossible de charger les films les mieux notés.',
              onRetry: _refresh,
            );
          }
          final page = snapshot.data;
          final movies = page?.movies ?? const <Movie>[];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: movies.length + (page?.fromCache == true ? 1 : 0),
              itemBuilder: (context, index) {
                if (page?.fromCache == true && index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Hors-ligne : dernières données disponibles.',
                      style: TextStyle(color: Colors.orangeAccent),
                    ),
                  );
                }
                final movie = movies[
                  page?.fromCache == true ? index - 1 : index
                ];
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
            ),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}