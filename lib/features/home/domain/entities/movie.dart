class Movie {
  const Movie({
    required this.id,
    required this.title,
    this.overview,
    this.posterUrl,
    this.releaseDate,
    this.rating,
    this.genres = const [],
  });

  final String id;
  final String title;
  final String? overview;
  final String? posterUrl;
  final DateTime? releaseDate;
  final double? rating;
  final List<String> genres;

  factory Movie.fromJson(Map<String, dynamic> json) {
    final releaseDate = json['release_date'] ?? json['releaseDate'];
    final rating = json['rating'] ?? json['vote_average'];
    final poster =
        json['poster_url'] ?? json['posterUrl'] ?? json['poster_path'];

    return Movie(
      id: '${json['id'] ?? json['movie_id'] ?? json['title']}',
      title: '${json['title'] ?? json['name'] ?? 'Film sans titre'}',
      overview: _stringValue(json['overview'] ?? json['description']),
      posterUrl: _stringValue(poster),
      releaseDate: releaseDate is String
          ? DateTime.tryParse(releaseDate)
          : null,
      rating: rating is num ? rating.toDouble() : double.tryParse('$rating'),
      genres: (json['genres'] is List)
          ? (json['genres'] as List)
                .map(
                  (genre) => genre is Map ? '${genre['name'] ?? ''}' : '$genre',
                )
                .where((genre) => genre.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_url': posterUrl,
      'release_date': releaseDate?.toIso8601String(),
      'rating': rating,
      'genres': genres,
    };
  }

  static String? _stringValue(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }
}
