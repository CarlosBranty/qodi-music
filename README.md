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

## Deploy

### CI/CD (GitHub Actions → GHCR → Dokploy)

Every push to `main` runs `.github/workflows/ci-cd.yml`:

1. **Server tests** (`cargo clippy`, `cargo test`) and **App tests** (`flutter analyze`, `flutter test`).
2. **Build and push**: the Docker image (server + web client) is pushed to `ghcr.io/cbranty/qodi-music` with tags `latest` and `sha-<short>` (plus `X.Y.Z` for `vX.Y.Z` tags).
3. **Deploy**: if the `DOKPLOY_WEBHOOK_URL` repository secret is set, Dokploy is called and pulls the new image. The server never compiles anything.

One-time setup:

1. **GHCR access on the server**: the package is private. Create a GitHub token with `read:packages` and add it in Dokploy → *Settings → Registry* (`ghcr.io`, user `cbranty`), or run `docker login ghcr.io` on the server.
2. **Dokploy service**: create a **Compose** service from this repository (compose path `docker-compose.yml`) and set the variables from `.env.example` in its environment.
3. **Webhook**: copy the service's deploy webhook URL from Dokploy and save it as a secret:
   ```bash
   gh secret set DOKPLOY_WEBHOOK_URL --body "<webhook url>"
   ```
4. **Domain**: in Dokploy → *Domains*, map `music.<your-domain>` to service `qodi-music`, port `4040`. Remove the `ports:` mapping if only the tunnel should reach it. Do **not** put Cloudflare Access in front of it: mobile clients cannot complete the Access login.

Roll back by setting `QODI_TAG=sha-<short>` and redeploying.

### Manual

```bash
cp .env.example .env      # set QODI_ADMIN_USER, QODI_ADMIN_PASSWORD, QODI_MUSIC_DIR
docker compose pull && docker compose up -d                                      # image from GHCR
docker compose -f docker-compose.yml -f docker-compose.build.yml up -d --build   # or build locally
curl http://localhost:4040/api/v1/health
```

- The music folder is mounted **read-only**; the database, transcode cache and generated JWT secret live in the `qodi-data` volume.
- The container runs as `QODI_UID:QODI_GID` (default `1000:1000`); that user must be able to read the music folder.
- New files are picked up automatically (filesystem watcher + periodic rescan).

### Getting new songs onto the server

Share a folder with [Syncthing](https://syncthing.net) between your workstation and the server, and set `QODI_MUSIC_DIR` to it. Tag files (title, artist, album, cover) with Picard or Kid3; put synced lyrics next to the audio as `<same-name>.lrc`.

## Client builds

```bash
cd app
flutter run -d linux                 # desktop
flutter build apk --release          # Android (requires the Android SDK)
```
