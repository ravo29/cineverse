import 'package:flutter/material.dart';

import '../../data/repositories/favorites_repository.dart';
import '../../domain/entities/movie.dart';
import '../../domain/usecases/toggle_favorite_usecase.dart';
import 'movie_detail_screen.dart';

// Palette violette partagée avec le flux d'authentification.
const _bgTop = Color(0xFF150029);
const _bgBottom = Color(0xFF000000);
const _accentStart = Color(0xFFB985FF);
const _accentEnd = Color(0xFF7B2FF7);
const _cardFill = Color(0xFF1E0B33);
const _cardBorder = Color(0xFF3A1B5C);

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _favoritesUseCase = ToggleFavoriteUseCase(
    repository: FavoritesRepositoryImpl(),
  );
  List<Movie> _favorites = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _favoritesUseCase.getFavorites();
      if (!mounted) return;
      setState(() => _favorites = result.favorites);
      if (result.fromCache) _showOfflineMessage();
    } on Exception {
      if (mounted) {
        setState(() => _errorMessage = 'Impossible de charger les favoris.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOfflineMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _cardBorder,
          content: Text('Hors-ligne : favoris locaux affichés.'),
          duration: Duration(seconds: 3),
        ),
      );
  }

  Future<void> _removeFavorite(Movie movie) async {
    setState(() => _favorites.removeWhere((item) => item.id == movie.id));

    final result = await _favoritesUseCase.remove(movie);
    if (!mounted || result.synced) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _cardBorder,
          content: Text('Retiré localement, synchronisation en attente.'),
          duration: Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBottom,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_accentStart, _accentEnd],
          ).createShader(bounds),
          child: const Text(
            'Mes favoris',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
            stops: [0.0, 0.4],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadFavorites,
          color: _accentStart,
          backgroundColor: _cardFill,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _accentStart),
                )
              : _errorMessage != null
              ? _EmptyFavorites(
                  message: _errorMessage!,
                  icon: Icons.wifi_off_rounded,
                )
              : _favorites.isEmpty
              ? const _EmptyFavorites(
                  message: 'Aucun favori pour le moment.',
                  icon: Icons.favorite_border_rounded,
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    kToolbarHeight + 24,
                    16,
                    24,
                  ),
                  itemCount: _favorites.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final movie = _favorites[index];
                    return _FavoriteTile(
                      movie: movie,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MovieDetailScreen(movieId: movie.id),
                        ),
                      ),
                      onRemove: () => _removeFavorite(movie),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.movie,
    required this.onTap,
    required this.onRemove,
  });

  final Movie movie;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 80,
                    child: movie.posterUrl == null
                        ? const ColoredBox(
                            color: _cardBorder,
                            child: Icon(
                              Icons.movie_outlined,
                              color: Colors.white38,
                            ),
                          )
                        : Image.network(movie.posterUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (movie.rating != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: _accentStart,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              movie.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Retirer des favoris',
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _cardFill,
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Icon(icon, color: _accentStart, size: 30),
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}