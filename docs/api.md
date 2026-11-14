# Qodi Music API v1

Contract between `server/` (Rust) and `app/` (Flutter). Both sides MUST follow it exactly.

## Conventions

- Base path: `/api/v1`. JSON bodies use `snake_case`. Timestamps are RFC 3339 UTC strings (`2026-11-13T20:15:00Z`).
- Auth: every endpoint except `GET /health` and `POST /auth/login` requires a JWT, sent as
  `Authorization: Bearer <token>` **or** as query parameter `?token=<token>` (needed by `<audio>`/`<img>` on web).
- Errors: non-2xx responses return `{"error": {"code": "<snake_case>", "message": "<human text>"}}`.
  Codes: `unauthorized` (401), `invalid_credentials` (401), `not_found` (404), `bad_request` (400), `internal` (500).
- Lists return `{"items": [...], "total": <int>}`. Pagination: `limit` (default 100, max 1000) and `offset` (default 0).
- IDs are lowercase hex strings, stable across rescans:
  - track id = first 16 hex chars of SHA-256 of the file path relative to the music dir (forward slashes).
  - album id = first 16 hex of SHA-256 of `lower(album_artist) + "\u0000" + lower(album)`.
  - artist id = first 16 hex of SHA-256 of `lower(artist)`.
- Missing tags fall back to: title = file stem, artist = `Unknown Artist`, album = parent folder name.

## Objects

```jsonc
// Track
{
  "id": "9f2c1a7b3d4e5f60", "title": "Semestre de Otoño",
  "artist": "José Madero", "artist_id": "…", "album": "Querido", "album_id": "…",
  "album_artist": "José Madero", "track_number": 3, "disc_number": 1, "year": 2023,
  "genre": "Pop", "duration_ms": 214000, "format": "flac", "bitrate_kbps": 900,
  "size_bytes": 25000000, "has_cover": true, "has_lyrics": false,
  "favorite": false, "updated_at": "2026-11-13T20:15:00Z"
}
// Album
{ "id": "…", "title": "Querido", "artist": "José Madero", "artist_id": "…", "year": 2023,
  "track_count": 12, "duration_ms": 2600000, "cover_track_id": "9f2c1a7b3d4e5f60" }
// Artist
{ "id": "…", "name": "José Madero", "album_count": 3, "track_count": 36 }
// Playlist
{ "id": "…", "name": "Night drive", "track_count": 20, "duration_ms": 4300000,
  "cover_track_id": "…", "created_at": "…", "updated_at": "…" }
```

Nullable fields: `track_number`, `disc_number`, `year`, `genre`, `bitrate_kbps`, `album.year`,
`album.cover_track_id`, `playlist.cover_track_id`.

## Endpoints

| Method | Path | Body / query | Response |
|---|---|---|---|
| GET | `/health` | – | `{"status":"ok","version":"0.1.0"}` |
| POST | `/auth/login` | `{"username","password"}` | `{"token","user":{"id","username"}}` · 401 `invalid_credentials` |
| GET | `/me` | – | `{"id","username"}` |
| GET | `/tracks` | `q`, `artist_id`, `album_id`, `limit`, `offset` | list of Track (sorted artist, album, disc, track, title). `q` matches title/artist/album, case-insensitive |
| GET | `/tracks/{id}` | – | Track |
| GET | `/tracks/{id}/stream` | `format=original\|opus` (default `original`), `bitrate=64\|96\|128\|192` (default 128, opus only) | audio bytes. **Must honor `Range`** (206 + `Content-Range`, `Accept-Ranges: bytes`) for both formats. Opus is transcoded once with ffmpeg into the data cache (`audio/ogg`) |
| GET | `/tracks/{id}/cover` | – | image bytes (embedded art, else `cover.jpg`/`folder.jpg`/`cover.png` in the track folder) · 404 if none |
| GET | `/tracks/{id}/waveform` | – | `{"peaks":[120 floats in 0..1]}` computed on first request and cached |
| GET | `/tracks/{id}/lyrics` | – | `{"synced":bool,"lines":[{"time_ms":int\|null,"text":str}]}` from sidecar `<stem>.lrc` or embedded lyrics tag · 404 if none |
| GET | `/albums` | `artist_id`, `limit`, `offset` | list of Album (sorted artist, year, title) |
| GET | `/albums/{id}` | – | `{"album":Album,"tracks":[Track]}` |
| GET | `/artists` | `limit`, `offset` | list of Artist (sorted name) |
| GET | `/playlists` | – | list of Playlist (sorted updated_at desc) |
| POST | `/playlists` | `{"name"}` | 201 Playlist |
| GET | `/playlists/{id}` | – | `{"playlist":Playlist,"tracks":[Track]}` (playlist order) |
| PATCH | `/playlists/{id}` | `{"name"?, "track_ids"?}` (`track_ids` replaces the whole ordered list) | Playlist |
| DELETE | `/playlists/{id}` | – | 204 |
| GET | `/favorites` | – | list of Track (most recently favorited first) |
| PUT | `/favorites/{track_id}` | – | 204 (idempotent) |
| DELETE | `/favorites/{track_id}` | – | 204 (idempotent) |
| POST | `/plays` | `{"plays":[{"client_id":uuid,"track_id","played_at","listened_ms"}]}` | `{"accepted":int}` — duplicates by `client_id` are ignored and not counted |
| GET | `/stats/summary` | `range=7d\|30d\|all` (default `30d`) | see below |
| GET | `/library/changes` | `since` (RFC 3339, optional; omitted = full snapshot) | `{"server_time","tracks":[Track],"removed_track_ids":[id]}` |
| POST | `/library/scan` | – | 202 `{"status":"scanning"}` (starts a rescan in the background) |

```jsonc
// GET /stats/summary
{
  "range": "30d", "total_plays": 120, "total_listen_ms": 25000000, "unique_tracks": 48,
  "top_tracks": [{ "track": Track, "plays": 12 }],          // max 10
  "top_artists": [{ "artist_id": "…", "name": "…", "plays": 30 }], // max 10
  "daily": [{ "date": "2026-11-13", "listen_ms": 3600000 }]  // one entry per day in range with plays, ascending
}
```

## Server behavior

- Supported files: `mp3, flac, ogg, opus, m4a, aac, wav`.
- Library is scanned at startup, on filesystem changes (debounced watcher), every `QODI_SCAN_INTERVAL_SECS`, and on `POST /library/scan`.
- Removed files become tombstones reported by `/library/changes` as `removed_track_ids`.
- `/` serves the Flutter web build from `QODI_WEB_DIR` when present (SPA fallback to `index.html` for non-`/api` paths).

## Server configuration (env)

| Var | Default | Meaning |
|---|---|---|
| `QODI_BIND` | `0.0.0.0:4040` | listen address |
| `QODI_MUSIC_DIR` | `/music` | library root (read-only) |
| `QODI_DATA_DIR` | `/data` | SQLite DB, transcode cache, generated secret |
| `QODI_WEB_DIR` | `/app/web` | Flutter web build (optional) |
| `QODI_JWT_SECRET` | generated and persisted in data dir | token signing secret |
| `QODI_TOKEN_TTL_DAYS` | `30` | token lifetime |
| `QODI_ADMIN_USER` / `QODI_ADMIN_PASSWORD` | – | creates this user on startup when it does not exist |
| `QODI_SCAN_INTERVAL_SECS` | `3600` | periodic full rescan |
