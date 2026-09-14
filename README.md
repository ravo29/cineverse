# CineVerse

CineVerse est une application Flutter de découverte de films. Elle utilise TMDB pour le catalogue et Supabase pour l'authentification et la synchronisation des favoris.

## Fonctionnalités

- Connexion et inscription Supabase avec stockage sécurisé de session.
- Renouvellement automatique du token après une réponse HTTP `401`.
- Intercepteur HTTP `AuthenticatedClient` : injection du bearer token, refresh via `AuthRepository`, puis rejeu de la requête initiale.
- Catalogue paginé des films populaires depuis TMDB.
- Écran de détail d'un film avec note, genres, synopsis et poster.
- Écran des favoris synchronisés avec Supabase REST.
- Cache local Hive pour les pages TMDB et les favoris.
- Mode hors-ligne : les dernières données locales restent consultables et les modifications de favoris sont mises en file d'attente.
- La queue Hive est dédupliquée par utilisateur et film, puis rejouée à la prochaine lecture ou modification des favoris. L'interface affiche le nombre d'opérations en attente.
- Messages utilisateur pour les erreurs réseau, d'authentification, de quota et de serveur.

## Architecture

Le projet suit une organisation Feature-First avec séparation Clean Architecture :

```text
lib/
	core/                       erreurs et infrastructure partagée
	features/auth/
		data/                     providers, session et client authentifié
		domain/                   use cases
		presentation/             écrans de connexion et splash
	features/home/
		data/                     providers, cache et repositories
		domain/                   entités et use cases
		presentation/             catalogue, détail et favoris
test/                         tests unitaires des repositories
```

Les écrans dépendent des use cases, les use cases dépendent des interfaces de repository et les repositories encapsulent les providers HTTP/cache. `SessionStorage` abstrait `flutter_secure_storage`, ce qui rend le refresh et les tests injectables. Cette structure permet de remplacer le réseau par des doublures dans les tests.

## Configuration et lancement

Prérequis : Flutter 3.44 ou supérieur, Dart 3.12 ou supérieur, une instance Supabase et une clé TMDB.

```powershell
flutter pub get
flutter run -d chrome `
	--dart-define=SUPABASE_URL=http://127.0.0.1:54321 `
	--dart-define=SUPABASE_ANON_KEY=votre_cle_anon `
	--dart-define=API_BASE_URL=http://127.0.0.1:54321 `
	--dart-define=TMDB_API_KEY=votre_cle_tmdb
```

Un token TMDB Read Access peut remplacer la clé API avec `TMDB_BEARER_TOKEN`. Ne versionnez jamais les clés ou tokens : utilisez des variables d'environnement ou des secrets CI.

## API utilisées

- Supabase Auth : `POST /auth/v1/token?grant_type=password`, `POST /auth/v1/token?grant_type=refresh_token` et `POST /auth/v1/signup`.
- Supabase REST : lecture, ajout et suppression des favoris via `/rest/v1/favorites`.
- TMDB : `GET /3/movie/popular`, `GET /3/movie/top_rated` et `GET /3/movie/{movie_id}` avec langue `fr-FR`.

## Vérification

```powershell
flutter analyze
flutter test
```

La CI GitHub Actions exécute ces deux commandes sur chaque push et pull request.
