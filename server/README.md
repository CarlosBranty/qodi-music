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

## Users and invites

There is no open signup. `QODI_ADMIN_USER` is created on first start from
`QODI_ADMIN_PASSWORD` and is made admin on every start; an existing user keeps its
password (the env password is never applied to it again). Every other user joins
with an invite:

```sh
# As admin: create an invite (defaults: 72 h, 1 use; limits 1–720 h, 1–50 uses)
curl -s -X POST localhost:4040/api/v1/admin/invites -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' -d '{"expires_in_hours": 48, "max_uses": 1}' | jq -r .code

# The new listener registers with it and gets a token, like login
curl -s localhost:4040/api/v1/auth/register -H 'content-type: application/json' \
  -d '{"invite_code":"K7Q2MX9RTA4P","username":"friend","password":"at-least-8"}'
```

- Codes are 12 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`, drawn from the OS
  CSPRNG. Registration checks the invite and consumes one use in the same
  `BEGIN IMMEDIATE` transaction that creates the user, so concurrent sign-ups cannot
  exceed `max_uses`.
- Usernames are stored lowercase and must match `^[a-z0-9_.-]{3,32}$`; login also
  accepts the name typed with capitals. Passwords are 8–128 characters.
- `GET /admin/users`, `DELETE /admin/users/{id}` (removes the user's playlists,
  favorites and plays; their tokens stop working at once), `GET /admin/invites`,
  `DELETE /admin/invites/{code}`. Non-admins get 403 `forbidden`. Admins cannot
  delete themselves, so at least one admin always remains.
- `PUT /me/password` changes your own password (requires the current one).

## Upgrading an existing database

Migrations only add columns and tables (`0002_users_invites_quality.sql`), so
users, playlists, favorites and plays are kept. After the upgrade nobody is admin
until startup promotes `QODI_ADMIN_USER`. Tracks indexed by the previous release
have no audio quality data (`sample_rate_hz`, `bit_depth`, `channels`, `lossless`);
the first scan re-reads each of them once even though size and mtime are unchanged,
and bumps `updated_at` so `/library/changes` delivers them to clients.

## Android updates

`GET /api/v1/app/android` and `GET /downloads/android/{file}` are public. Both read
`{QODI_DIST_DIR}/android/` (default `/app/dist/android/`) on every request, so a CI
redeploy that replaces `latest.json` and the APK is picked up without a restart. A
missing dist dir or invalid `latest.json` gives 404. Downloads accept only a single
plain file name (no listing, no traversal) and support `Range`.

## Layout

| Module | Responsibility |
|---|---|
| `library` | Track/album/artist domain, id derivation, incremental scanner |
| `streaming` | Stream formats, Opus cache, waveform peaks |
| `lyrics` | LRC / plain lyrics parsing |
| `playlists`, `favorites`, `stats` | Per-user features and their ports |
| `auth` | Users, admin flag, invites, password hashing, JWT |
| `adapters` | SQLite store, lofty tags, symphonia waveform, ffmpeg, fs watcher |
| `http` | axum routes, auth/admin extractors, contract error shape, downloads, SPA fallback |

## Tests

```sh
cargo test
cargo clippy --all-targets -- -D warnings
```

The integration tests (`tests/api.rs`, `accounts.rs`, `quality.rs`,
`distribution.rs`, sharing `tests/common/`) build the router against temporary
music and data directories, generate WAV fixtures, and call the HTTP API.
`quality.rs` also upgrades a database created by `0001_init.sql` alone. Tests that
need `ffmpeg` (Opus transcoding, generated MP3/Opus/AAC/ALAC/FLAC files) are
skipped when it is not on `PATH`.
