import 'package:flutter/material.dart';

import '../../data/providers/favorites_provider.dart';
import '../../data/providers/movies_provider.dart';
import '../../domain/entities/movie.dart';
import '../../domain/usecases/get_movie_details_usecase.dart';
import '../../domain/usecases/toggle_favorite_usecase.dart';

// Palette violette partagée avec le reste de l'application.
const _bgTop = Color(0xFF150029);
const _bgBottom = Color(0xFF000000);
const _accentStart = Color(0xFFB985FF);
const _accentEnd = Color(0xFF7B2FF7);
const _cardFill = Color(0xFF1E0B33);
const _cardBorder = Color(0xFF3A1B5C);

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({required this.movieId, super.key});

  final String movieId;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late final Future<Movie> _movieFuture = GetMovieDetailsUseCase(
    provider: RestMoviesProvider(),
  )(movieId: widget.movieId);
  final _toggleFavorite = ToggleFavoriteUseCase(provider: FavoritesProvider());
  bool? _isFavorite;
  bool _isUpdatingFavorite = false;
  Movie? _loadedMovie;

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    await _toggleFavorite.synchronizePending();
    final isFavorite = await _toggleFavorite.isFavorite(widget.movieId);
    if (mounted) setState(() => _isFavorite = isFavorite);
  }

  Future<void> _toggleMovieFavorite(Movie movie) async {
    if (_isUpdatingFavorite) return;
    setState(() => _isUpdatingFavorite = true);

    try {
      final result = await _toggleFavorite(movie);
      if (!mounted) return;
      setState(() => _isFavorite = result.isFavorite);
      if (!result.synced) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: _cardBorder,
              content: Text(
                'Favori enregistré localement, synchronisation en attente.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: _cardBorder,
              content: Text('Impossible de modifier les favoris.'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingFavorite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBottom,
      body: FutureBuilder<Movie>(
        future: _movieFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _accentStart),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white70, size: 18),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _cardFill,
                        border: Border.all(color: _cardBorder),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: _accentStart,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      snapshot.error is MoviesException
                          ? (snapshot.error! as MoviesException).message
                          : 'Impossible de charger le film.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }
          _loadedMovie = snapshot.data!;
          return _MovieDetails(
            movie: snapshot.data!,
            isFavorite: _isFavorite,
            isUpdatingFavorite: _isUpdatingFavorite,
            onToggleFavorite: () => _toggleMovieFavorite(_loadedMovie!),
          );
        },
      ),
    );
  }
}

class _MovieDetails extends StatelessWidget {
  const _MovieDetails({
    required this.movie,
    required this.isFavorite,
    required this.isUpdatingFavorite,
    required this.onToggleFavorite,
  });

  final Movie movie;
  final bool? isFavorite;
  final bool isUpdatingFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 340,
          backgroundColor: _bgBottom,
          // Empêche Flutter de recopier la largeur du leading sur les actions
          // pour "centrer" le titre : c'est ce qui provoquait l'overflow.
          centerTitle: false,
          titleSpacing: 0,
          leadingWidth: 56,
          leading: Center(
            child: _CircleIconButton(
              icon: Icons.arrow_back_ios_new,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          actions: [
            // Zone de largeur fixe : qu'il y ait un spinner ou un bouton,
            // les actions gardent toujours la même taille, sans overflow.
            SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: isFavorite == null
                    ? const SizedBox.shrink()
                    : isUpdatingFavorite
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : _CircleIconButton(
                        icon: isFavorite!
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        iconColor: isFavorite! ? _accentStart : Colors.white,
                        onTap: onToggleFavorite,
                      ),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                movie.posterUrl == null
                    ? const ColoredBox(
                        color: _cardFill,
                        child: Icon(
                          Icons.movie_outlined,
                          size: 64,
                          color: Colors.white38,
                        ),
                      )
                    : Image.network(movie.posterUrl!, fit: BoxFit.cover),
                // Dégradé pour fondre le poster dans le fond violet/noir.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, _bgBottom],
                      stops: [0.45, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bgTop, _bgBottom],
                stops: [0.0, 0.5],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, _accentStart],
                    ).createShader(bounds),
                    child: Text(
                      movie.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (movie.rating != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _cardFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: _accentStart, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${movie.rating!.toStringAsFixed(1)} / 10',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (movie.genres.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: movie.genres
                          .map(
                            (genre) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [_accentStart, _accentEnd],
                                ),
                              ),
                              child: Text(
                                genre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Synopsis',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    movie.overview?.isNotEmpty == true
                        ? movie.overview!
                        : 'Aucun synopsis disponible.',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14.5,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: iconColor, size: 18),
        // Taille de tap contrainte explicitement : évite que le IconButton
        // réclame son minimum Material (48x48) et déborde du slot alloué.
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}