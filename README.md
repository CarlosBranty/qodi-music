# Qodi Music

Personal music streaming: a Rust server that indexes and streams your own library, and a Flutter client for Android, Linux, web, and more.

```
Syncthing ──► /music (read-only) ──► qodi-server (Rust, SQLite) ──► Cloudflare Tunnel ──► Flutter clients
                                         └── serves the Flutter web client at /
```

| Part | Path | Docs |
|---|---|---|
| Server (Rust, axum) | `server/` | [server/README.md](server/README.md) |
| Client (Flutter) | `app/` | [app/README.md](app/README.md) |
| API contract | `docs/api.md` | [docs/api.md](docs/api.md) |

## Deploy with Docker Compose

```bash
cp .env.example .env      # set QODI_ADMIN_USER, QODI_ADMIN_PASSWORD, QODI_MUSIC_DIR
docker compose up -d --build
curl http://localhost:4040/api/v1/health
```

Open `http://<server>:4040` for the web client, or point the mobile/desktop app at the same URL.

- The music folder is mounted **read-only**; the database, transcode cache and generated JWT secret live in the `qodi-data` volume.
- The container runs as `QODI_UID:QODI_GID` (default `1000:1000`); that user must be able to read the music folder.
- New files are picked up automatically (filesystem watcher + periodic rescan).

### Dokploy + Cloudflare Tunnel

1. Create a **Compose** service from this repository (compose path `docker-compose.yml`).
2. Set the variables from `.env.example` in the service environment.
3. In **Domains**, map `music.<your-domain>` to service `qodi-music`, port `4040`. You can remove the `ports:` mapping if only the tunnel should reach it.
4. Do **not** put Cloudflare Access in front of it: mobile clients cannot complete the Access login. The server enforces its own authentication.

### Getting new songs onto the server

Share a folder with [Syncthing](https://syncthing.net) between your workstation and the server, and set `QODI_MUSIC_DIR` to it. Tag files (title, artist, album, cover) with Picard or Kid3; put synced lyrics next to the audio as `<same-name>.lrc`.

## Client builds

```bash
cd app
flutter run -d linux                 # desktop
flutter build apk --release          # Android (requires the Android SDK)
```
