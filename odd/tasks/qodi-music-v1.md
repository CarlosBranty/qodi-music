# qodi-music v1
Objective: personal Spotify-like system — Rust server streaming the user's library, Flutter multiplatform client, deployed with Docker Compose.
Branch: `feat/qodi-music-v1` · Delivery: ask-on-risk · Runners: `cargo test` (server), `flutter test` (app).

## Specs

- S1 "nombra la carpeta qodi-music, hazlo todo en una pasada todas las fases para desplegar con docker compose" — repo at `~/Projects/qodi-music`, all phases F0–F5 in one pass, deployable with `docker compose up`.
- S2 Server in Rust: "el backend que contenga las canciones en el servidor en rust" — scans the music dir, streams with Range, auth, opus transcoding, covers, waveform, lyrics, playlists, favorites, plays/stats, delta sync. Contract: `docs/api.md`.
- S3 Client in Flutter, multiplatform ("me gustaria que se pueda usar en multiplataforma"): Android, Linux, web (iOS/Windows/macOS scaffolded). Background playback + media controls; offline downloads on native.
- S4 UI "que tenga este interfaz el cliente": style of the two reference images — beige `#EFE6DD`, orange `#E8653F`, navy `#0F2233`, black pill nav bar, vinyl covers, bento stat cards, arc waveform seekbar with big orange play button, lyrics sheet, dark mode.
- S5 Deploy: one Compose stack (server + web client) for Dokploy behind the existing Cloudflare tunnel; music volume read-only; songs arrive via Syncthing into the music dir.

## Tasks

| ID | Specs | Route | Status | Commit |
|---|---|---|---|---|
| T1 | S2 | delegated (writer trigger a: parallel with T2, disjoint `server/**`) | done — cargo test 19/19, clippy clean | 1f7bdf4 |
| T2 | S3, S4 | delegated (writer trigger a: parallel with T1, disjoint `app/**`) | done — analyze clean, 36 tests, linux+web builds | beae5bd |
| T3 | S1, S5 | inline (Dockerfile, compose, README) | done — docker build NOT run (no Docker locally) | e605f83, eeb94f9 |
| T4 | S2 | independent verifier — Risk item 2 (auth/token handling) | done — 0 blockers, 6 advisories (2 fixed) | see HEAD |

## Log

- L1 (2026-11-13) "nombra la carpeta qodi-music, hazlo todo en una pasada todas las fases para desplegar con docker compose" — prior turn: "ok entonce flutter que tenga este interfaz el cliente, y el backend que contrenda las cnaciones en el servidor en rust? dame esl esquema completo del plan" (two reference images).
- L2 Environment: Rust 1.99 + ffmpeg present; Flutter installed to `~/develop/flutter`; Docker absent locally, so the compose build cannot be run here.
- L3 T4 verdict: no blockers. Fixed advisories: per-user play dedupe, data dir 0700. Open advisories: JWT secret min length, login rate limit (use Cloudflare rule), `?token=` in proxy logs, no token revocation.
- L4 Seam check: server serves the web build at `/` with SPA fallback; plays/playlists payloads from the app accepted. Pending: `docker compose build`, Android APK, real-device background playback test.
