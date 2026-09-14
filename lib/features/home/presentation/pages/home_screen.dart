import 'package:flutter/material.dart';

import '../../../auth/data/providers/auth_provider.dart';
import '../../data/providers/favorites_provider.dart';
import '../../data/providers/movies_provider.dart';
import '../../domain/entities/movie.dart';
import '../../domain/usecases/get_popular_movies_usecase.dart';
import '../../domain/usecases/toggle_favorite_usecase.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/movies_repository.dart';
import 'favorites_screen.dart';
import 'movie_detail_screen.dart';
import 'top_rated_screen.dart';

// Palette violette partagée avec le reste de l'application.
const _bgTop = Color(0xFF150029);
const _bgBottom = Color(0xFF000000);
const _accentStart = Color(0xFFB985FF);
const _accentEnd = Color(0xFF7B2FF7);
const _cardFill = Color(0xFF1E0B33);
const _cardBorder = Color(0xFF3A1B5C);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _pageSize = 20;
  static const _paginationThreshold = 300.0;

  final _scrollController = ScrollController();
  final _getPopularMovies = GetPopularMoviesUseCase(
    repository: MoviesRepositoryImpl(),
  );
  final _secureTokenProvider = SecureTokenProvider();
  final List<Movie> _movies = [];
  int _page = 1;
  bool _hasMore = true;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialMovies();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitialMovies() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _getPopularMovies(page: 1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _movies
          ..clear()
          ..addAll(result.movies);
        _page = 1;
        _hasMore = result.hasMore;
      });
      if (result.fromCache && mounted) {
        _showOfflineMessage();
      }
    } on MoviesException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMore || _isInitialLoading) return;
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final result = await _getPopularMovies(
        page: nextPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _movies.addAll(result.movies);
        _page = nextPage;
        _hasMore = result.hasMore;
      });
      if (result.fromCache && mounted) {
        _showOfflineMessage();
      }
    } on MoviesException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < _paginationThreshold) {
      _loadNextPage();
    }
  }

  Future<void> _refresh() => _loadInitialMovies();

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _cardBorder),
        ),
        title: const Text(
          'Déconnexion',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter ?',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accentEnd),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    try {
      await _secureTokenProvider.clear();
      await FavoritesProvider().clearLocalData();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } on Exception {
      if (!mounted) return;
      _showError('Impossible de terminer la déconnexion.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _cardBorder,
          content: Text(message),
        ),
      );
  }

  void _showOfflineMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _cardBorder,
          content: Text('Mode hors-ligne : données locales affichées.'),
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
            'Films populaires',
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Films les mieux notés',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TopRatedScreen()),
            ),
            icon: const Icon(Icons.star_border_rounded, color: Colors.white70),
          ),
          IconButton(
            tooltip: 'Mes favoris',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
            ),
            icon: const Icon(Icons.favorite_border_rounded, color: Colors.white70),
          ),
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
            stops: [0.0, 0.35],
          ),
        ),
        child: _isInitialLoading && _movies.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: _accentStart),
              )
            : RefreshIndicator(
                onRefresh: _refresh,
                color: _accentStart,
                backgroundColor: _cardFill,
                child: _movies.isEmpty
                    ? ListView(
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
                                    child: const Icon(
                                      Icons.movie_filter_outlined,
                                      color: _accentStart,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    _errorMessage ?? 'Aucun film disponible.',
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
                      )
                    : _buildMovieGrid(),
              ),
      ),
    );
  }

  Widget _buildMovieGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.58,
      ),
      itemCount: _movies.length + (_isLoadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _movies.length) {
          return const Center(
            child: CircularProgressIndicator(color: _accentStart),
          );
        }
        return _MovieCard(movie: _movies[index]);
      },
    );
  }
}

class _MovieCard extends StatefulWidget {
  const _MovieCard({required this.movie});

  final Movie movie;

  @override
  State<_MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<_MovieCard> {
  final _favorites = ToggleFavoriteUseCase(
    repository: FavoritesRepositoryImpl(),
  );
  bool? _isFavorite;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    final isFavorite = await _favorites.isFavorite(widget.movie.id);
    if (mounted) setState(() => _isFavorite = isFavorite);
  }

  Future<void> _toggleFavorite() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      final result = await _favorites(widget.movie);
      if (!mounted) return;
      setState(() => _isFavorite = result.isFavorite);
      if (!result.synced) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: _cardBorder,
              content: Text(
                'Favori enregistré localement. '
                '${result.pendingOperations} opération(s) en attente.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _cardBorder,
            content: Text('Impossible de modifier le favori.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MovieDetailScreen(movieId: widget.movie.id),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.movie.posterUrl == null
                          ? const ColoredBox(
                              color: _cardBorder,
                              child: Icon(
                                Icons.movie_outlined,
                                size: 40,
                                color: Colors.white38,
                              ),
                            )
                          : Image.network(
                              widget.movie.posterUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: _cardBorder,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 40,
                                  color: Colors.white38,
                                ),
                              ),
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(
                                        color: _accentStart,
                                      ),
                                    ),
                            ),
                      // Voile sombre en bas pour la lisibilité du titre (style poster).
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 48,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black54],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: _isFavorite == true
                                ? 'Retirer des favoris'
                                : 'Ajouter aux favoris',
                            onPressed: _isFavorite == null || _isUpdating
                                ? null
                                : _toggleFavorite,
                            icon: _isUpdating
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _isFavorite == true
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: _isFavorite == true
                                        ? _accentStart
                                        : Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      if (widget.movie.rating != null) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: _accentStart,
                              size: 15,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.movie.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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