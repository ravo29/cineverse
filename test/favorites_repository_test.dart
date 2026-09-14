import 'package:flutter_test/flutter_test.dart';

import 'package:cineverse/features/home/data/providers/favorites_provider.dart';
import 'package:cineverse/features/home/data/repositories/favorites_repository.dart';
import 'package:cineverse/features/home/domain/entities/movie.dart';

class _FakeFavoritesProvider extends FavoritesProvider {
  @override
  Future<bool> isFavorite(String movieId) async => movieId == '1';
}

void main() {
  test('repository delegates favorite lookup to its data source', () async {
    final repository = FavoritesRepositoryImpl(
      provider: _FakeFavoritesProvider(),
    );

    expect(await repository.isFavorite('1'), isTrue);
    expect(await repository.isFavorite('2'), isFalse);
  });

  test('repository exposes the domain movie contract', () {
    const movie = Movie(id: '1', title: 'Arrival');

    expect(movie.toJson()['title'], 'Arrival');
  });
}