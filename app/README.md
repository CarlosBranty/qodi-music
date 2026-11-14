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
- Music on the device itself (native only), with or without a server — see below.

## Music on this device

The app also plays audio files stored on the phone/computer, through the same
player (queue, background playback, media notification / MPRIS).

- **Use without server**: the login screen has a "Use without server" action.
  In that mode (persisted) the app makes no API calls: Explore and Stats show a
  "Connect to a server" empty state, Library shows only "On this device", Home
  shows device playlists, device favorites and device play history. Settings ›
  "Connect to a server" opens the login form; signing in leaves device-only
  mode and device music stays available next to the server library.
- **Library › On this device** (and the Home shortcut card): Songs / Albums /
  Artists / Favorites / Playlists, search, pull-to-refresh rescan.
- **Ids**: device tracks reuse the `Track` entity with ids `device:<hash of the
  absolute path>`, so they never collide with server ids. Device plays are
  never sent to `POST /plays`; favorites and playlists of device tracks are
  stored locally (drift tables `device_favorites`, `device_playlists`,
  `device_playlist_tracks`); server favorites/playlists are unchanged.
- **Scanning** runs in a background isolate and is incremental (size + mtime):
  only new or changed files are read again, removed files are dropped. Results
  are cached in the drift table `device_tracks` (schema v2 migration, existing
  data kept).
- **Metadata** is read with the pure-Dart `audio_metadata_reader` (MP3, FLAC,
  M4A/MP4, OGG, Opus, WAV, AIFF, APE). Missing tags fall back like the server:
  title = file name, artist = `Unknown Artist`, album = folder name. Embedded
  covers are extracted to the app cache dir (`device_covers/`, shared per
  image); otherwise a `cover.jpg` / `folder.jpg` next to the file is used.
  A sidecar `<song>.lrc` next to the file is shown in the lyrics sheet.
- **Folders**: Settings › "Music on this device" lists the default folders,
  lets you add/remove folders (folder picker) and rescan.

| Platform | What is scanned | Notes |
|---|---|---|
| Android | `/storage/emulated/0/Music`, `/storage/emulated/0/Download` + added folders | Asks for `READ_MEDIA_AUDIO` (API 33+) or `READ_EXTERNAL_STORAGE` (API ≤ 32). Denied → "Allow access" / "Open settings". Folders on SD cards work if the picker returns a real path. |
| Linux | `~/Music`, `XDG_MUSIC_DIR` + added folders | |
| Windows | `%USERPROFILE%\Music` + added folders | |
| macOS | `~/Music` + added folders | Sandbox entitlements: music folder (read-only) and user-selected files. Added folders are not kept across restarts (no security-scoped bookmarks yet). |
| iOS | Only files imported into the app (`Documents/Music`) | iOS does not let apps read the Music app library as files. Use Settings › "Import songs", or drop files into the app's `Music` folder in the Files app / Finder (file sharing is enabled). |
| Web | — | Hidden. |

## Layout

```
lib/
  core/      api client, config/prefs, theme tokens, router, platform split
  features/  auth, library, player, playlists, favorites, stats, lyrics,
             downloads, search, home, settings, device_music — each with
             domain/data/ui
  shared/    VinylCover, ArcWaveformSeekbar, BentoCard, PillNavBar, TrackTile, ...
```

Domain code is pure Dart (ports + logic); adapters live in `data/`; Riverpod
providers in `ui/` wire adapters to ports. Native-only code (drift database,
file downloads, device music scanning) is selected with a conditional import in
`core/platform/platform_services.dart`.

## Tests

```sh
flutter analyze
flutter test
```
