# qodi-music v1
Objective: personal Spotify-like system — Rust server streaming the user's library, Flutter multiplatform client, deployed with Docker Compose.
Branch: `feat/qodi-music-v1` · Delivery: ask-on-risk · Runners: `cargo test` (server), `flutter test` (app).

## Specs

- S1 "nombra la carpeta qodi-music, hazlo todo en una pasada todas las fases para desplegar con docker compose" — repo at `~/Projects/qodi-music`, all phases F0–F5 in one pass, deployable with `docker compose up`.
- S2 Server in Rust: "el backend que contenga las canciones en el servidor en rust" — scans the music dir, streams with Range, auth, opus transcoding, covers, waveform, lyrics, playlists, favorites, plays/stats, delta sync. Contract: `docs/api.md`.
- S3 Client in Flutter, multiplatform ("me gustaria que se pueda usar en multiplataforma"): Android, Linux, web (iOS/Windows/macOS scaffolded). Background playback + media controls; offline downloads on native.
- S4 UI "que tenga este interfaz el cliente": style of the two reference images — beige `#EFE6DD`, orange `#E8653F`, navy `#0F2233`, black pill nav bar, vinyl covers, bento stat cards, arc waveform seekbar with big orange play button, lyrics sheet, dark mode.
- S5 Deploy: one Compose stack (server + web client) for Dokploy behind the existing Cloudflare tunnel; music volume read-only; songs arrive via Syncthing into the music dir.
- S6 "ahora tambien funciona como reproductor de musica offline? paraque tome musica del propio telefono" + "Si hazlo": play music stored on the device itself. Decision (assistant default, user delegated): separate "On this device" section in Library; app usable without a server ("Use without server" on login); device tracks get local favorites/playlists; reuse the existing player. Android + Linux/Windows/macOS via folder scan; iOS limited to files imported into the app.
- S7 "quero adicionar que la app tenga un ecualizador" — equalizer (Android/iOS/macOS where the audio engine supports it; hidden elsewhere), presets + per-band gains, persisted.
- S8 "que se sea cuando una cancionesta preparado par aoffline o fue descargada" — clear offline/downloaded indicator on track rows, covers, Now Playing, album/playlist headers.
- S9 "que tenga tambien opcion al interfaz con todo en espa;ol" — English + Spanish UI, follows the device language, manual selector in Settings.
- S10 "es psible para que tenga un autoupdater? o no es psible en apk?" — Android self-update: CI builds signed APK, server publishes it, app checks/downloads/prompts install. Pending user decision on storing the keystore as a GitHub secret.
- S11 "tambien que se muestre que calidad tiene cada cancion" — per-track quality (format, bitrate, sample rate, bit depth, lossless/Hi-Res badge) from server fields.
- S12 "se puede registrar mas usuarios? deberia si alguien quiere unirse a escuchar" — invite-based registration, admin user/invite management, change password. Decision (assistant default): invite codes, no open signup.

## Tasks

| ID | Specs | Route | Status | Commit |
|---|---|---|---|---|
| T1 | S2 | delegated (writer trigger a: parallel with T2, disjoint `server/**`) | done — cargo test 19/19, clippy clean | 1f7bdf4 |
| T2 | S3, S4 | delegated (writer trigger a: parallel with T1, disjoint `app/**`) | done — analyze clean, 36 tests, linux+web builds | beae5bd |
| T3 | S1, S5 | inline (Dockerfile, compose, README) | done — docker build NOT run (no Docker locally) | e605f83, eeb94f9 |
| T5 | S6 | delegated (context backstop: unfamiliar 12k-line app/; reading prepares the write) | done — analyze clean, 74 tests, linux+web builds, Linux smoke scanned 3 FLAC | a925f62 |
| T6 | S7, S8 | delegated (context backstop; player + UI of the 14k-line app) | done — 102 tests, web/linux/apk builds; EQ Android-only | 3db2330 |
| T9 | S11, S12 (server) | delegated (writer trigger a: parallel with T6, disjoint `server/**`) | done — 36 tests, clippy clean; also S10 endpoints | 8847303 |
| T10 | S10 (app), S11, S12 (app) + in-app logo | delegated after T6 | done — 170 tests, web/linux/apk builds | fe44887 |
| T11 | S12 | independent verifier — Risk items 1, 2 | done — 0 blockers, 6 advisories (2 fixed) | HEAD |
| T7 | S9 | delegated after T10 (touches every UI string) | done — 328 keys, 189 tests, web/linux/apk builds | 12ce05d |
| T8 | S10 | CI inline (272cfc0); server endpoint in T9; app part in T10 | done — pending real-device install test | 272cfc0 |
| T4 | S2 | independent verifier — Risk item 2 (auth/token handling) | done — 0 blockers, 6 advisories (2 fixed) | see HEAD |

## Log

- L1 (2026-11-13) "nombra la carpeta qodi-music, hazlo todo en una pasada todas las fases para desplegar con docker compose" — prior turn: "ok entonce flutter que tenga este interfaz el cliente, y el backend que contrenda las cnaciones en el servidor en rust? dame esl esquema completo del plan" (two reference images).
- L2 Environment: Rust 1.99 + ffmpeg present; Flutter installed to `~/develop/flutter`; Docker absent locally, so the compose build cannot be run here.
- L3 T4 verdict: no blockers. Fixed advisories: per-user play dedupe, data dir 0700. Open advisories: JWT secret min length, login rate limit (use Cloudflare rule), `?token=` in proxy logs, no token revocation.
- L4 Seam check: server serves the web build at `/` with SPA fallback; plays/playlists payloads from the app accepted. Pending: `docker compose build`, Android APK, real-device background playback test.
- L5 (2026-11-13) "ok ahora tambien funciona como reproductor de musica offline? paraque tome musica del propio telefono" → verified: not supported (no storage permission, no device source, login required). User: "Si hazlo" (did not pick mixed vs separate; assistant chose separate section).
- L6 T5 done: Dart folder scan (audio_metadata_reader), drift schema v2 additive only (verified CREATE-only diff + migration test). Untested on device: Android permission/folder picker, iOS import, macOS sandbox bookmarks.
- L7 (2026-11-14) Web bug "a pesar que cambio de cancion ... me reproduce la misma cancion" reproduced in headless Firefox: just_audio_web reused its cached playlist; fixed with stop() before load on web (RED/GREEN test).
- L8 (2026-11-14) "Listo quero adicionar que la app tenga un ecualizador, que se sea cuando una cancionesta preparado par aoffline o fue descargada, y que tenga tambien opcion al interfaz con todo en espa;ol, es psible para que tenga un autoupdater? o no es psible en apk?"
- L9 (2026-11-14) "tambien que se muestre que calidad tiene cada cancion, y se puede registrar mas usuarios? deberia si alguien quiere unirse a escuchar" → verified: no registration endpoint; quality only format+bitrate. Contract extended (docs/api.md).
- L10 (2026-11-14) User chose option A: keystore stored as GitHub secrets (ANDROID_KEYSTORE_BASE64/PASSWORD/KEY_ALIAS).
- L11 T11: upgrade from 1f7bdf4 and 36672c3 DBs verified lossless; fixed advisories: invite pre-check before argon2, case-insensitive revoke. Open: password change does not revoke tokens; bootstrap exact-case match.
- L12 (2026-11-14) Production live at music.branty.lat; full CI/CD green (run 7): tests, signed APK v7, GHCR image, Dokploy webhook deploy. Push events still do not trigger Actions; runs dispatched manually.
