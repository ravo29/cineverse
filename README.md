# cineverse

A new Flutter project.

## Authentification API

L’écran de connexion utilise `POST /auth/login` et attend une réponse JSON
contenant `access_token`. Configurez l’URL de l’API au lancement :

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

## Films TMDB

La page d’accueil utilise `GET https://api.themoviedb.org/3/movie/popular`.
Fournissez une clé API TMDB au lancement :

```bash
flutter run --dart-define=TMDB_API_KEY=votre_cle_tmdb
```

Un token TMDB Read Access peut aussi être utilisé :

```bash
flutter run --dart-define=TMDB_BEARER_TOKEN=votre_token_tmdb
```
