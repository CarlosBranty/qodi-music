# qodi-server

Rust (axum + SQLite) server for Qodi Music. It scans a music folder, streams files
with HTTP Range support, transcodes to Opus on demand, and serves covers, lyrics,
waveforms, playlists, favorites, play stats and library deltas.

The API contract, including every `QODI_*` environment variable, is in
[`../docs/api.md`](../docs/api.md). `QODI_FFMPEG` (default `ffmpeg`) sets the
ffmpeg binary used for Opus transcoding.

## Run locally

```sh
QODI_MUSIC_DIR=~/Music \
QODI_DATA_DIR=$(mktemp -d) \
QODI_BIND=127.0.0.1:4040 \
QODI_ADMIN_USER=admin QODI_ADMIN_PASSWORD=change-me \
RUST_LOG=info \
cargo run --release
```

```sh
TOKEN=$(curl -s localhost:4040/api/v1/auth/login \
  -H 'content-type: application/json' \
  -d '{"username":"admin","password":"change-me"}' | jq -r .token)
curl -s localhost:4040/api/v1/tracks -H "authorization: Bearer $TOKEN" | jq '.total'
```

On startup the server creates the data dir, runs the migrations, generates
`{data}/jwt_secret` (mode 0600) if `QODI_JWT_SECRET` is unset, and starts the first
scan in the background. It answers requests right away. After that, rescans run
when files change (debounced watcher), every `QODI_SCAN_INTERVAL_SECS`, and on
`POST /api/v1/library/scan`.

## Layout

| Module | Responsibility |
|---|---|
| `library` | Track/album/artist domain, id derivation, incremental scanner |
| `streaming` | Stream formats, Opus cache, waveform peaks |
| `lyrics` | LRC / plain lyrics parsing |
| `playlists`, `favorites`, `stats`, `auth` | Per-user features and their ports |
| `adapters` | SQLite store, lofty tags, symphonia waveform, ffmpeg, fs watcher |
| `http` | axum routes, auth extractor, contract error shape, SPA fallback |

## Tests

```sh
cargo test
cargo clippy --all-targets -- -D warnings
```

`tests/api.rs` builds the router against temporary music and data directories,
generates WAV fixtures, and calls the HTTP API. The Opus test is skipped when
`ffmpeg` is not on `PATH`.
