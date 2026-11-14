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
| T1 | S2 | delegated (writer trigger a: parallel with T2, disjoint `server/**`) | pending | |
| T2 | S3, S4 | delegated (writer trigger a: parallel with T1, disjoint `app/**`) | pending | |
| T3 | S1, S5 | inline (Dockerfile, compose, README) | pending | |
| T4 | S2 | independent verifier — Risk item 2 (auth/token handling) | pending | |

## Log

- L1 (2026-11-13) "nombra la carpeta qodi-music, hazlo todo en una pasada todas las fases para desplegar con docker compose" — prior turn: "ok entonce flutter que tenga este interfaz el cliente, y el backend que contrenda las cnaciones en el servidor en rust? dame esl esquema completo del plan" (two reference images).
- L2 Environment: Rust 1.99 + ffmpeg present; Flutter installed to `~/develop/flutter`; Docker absent locally, so the compose build cannot be run here.
