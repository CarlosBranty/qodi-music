# Qodi Music — Flutter client

Multiplatform client (Android, Linux, web; iOS/Windows/macOS scaffolded) for the
Qodi Music server. API contract: [`../docs/api.md`](../docs/api.md).

## Run

```sh
cd app
flutter pub get

flutter run -d linux      # needs libmpv (mpv) installed
flutter run -d chrome     # web
flutter run -d <android>  # Android device/emulator
```

On first launch enter the server URL (e.g. `http://192.168.1.10:4040`), username
and password. On web the URL defaults to the page origin, so the web build served
by the server (`docker compose up`) needs no URL at all. Plain `http://` LAN
servers are allowed on Android/iOS.

Release builds: `flutter build web --release`, `flutter build linux --release`,
`flutter build apk --release`.

## Features

- Login with server URL; session stored locally; a `401` returns to login.
- Home: greeting, playlists carousel, recently played (vinyl cards), favorites.
- Explore: debounced search, albums grid, artists, album/artist detail.
- Library: playlists (create, rename, delete, add, reorder, remove), favorites,
  downloads (native only).
- Now Playing: spinning vinyl, queue carousel, arc waveform seekbar, repeat /
  shuffle / queue, favorites, synced or plain lyrics sheet.
- Mini player above the black pill nav bar; light/dark/system theme.
- Stats: listening time, plays, unique tracks, top-artist ring, daily bars,
  top tracks for 7 days / 30 days / all time.
- Plays: a session counts once when listened ≥ 30 s or finished; queued locally
  and sent to `POST /plays` (retried on start, resume and next play).
- Offline (native): download songs/albums/playlists; local files are preferred
  for playback; library cache synced via `/library/changes`.
- Background playback and OS media controls through `audio_service`
  (Android notification, iOS lock screen, MPRIS on Linux, Media Session on web).
- Streaming quality: original file or Opus 128 kbps (Settings).

## Layout

```
lib/
  core/      api client, config/prefs, theme tokens, router, platform split
  features/  auth, library, player, playlists, favorites, stats, lyrics,
             downloads, search, home, settings — each with domain/data/ui
  shared/    VinylCover, ArcWaveformSeekbar, BentoCard, PillNavBar, TrackTile, ...
```

Domain code is pure Dart (ports + logic); adapters live in `data/`; Riverpod
providers in `ui/` wire adapters to ports. Native-only code (drift database,
file downloads) is selected with a conditional import in
`core/platform/platform_services.dart`.

## Tests

```sh
flutter analyze
flutter test
```
