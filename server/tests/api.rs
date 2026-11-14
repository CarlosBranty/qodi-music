//! End-to-end tests through the public HTTP interface (`docs/api.md`).

use std::path::{Path, PathBuf};

use axum::Router;
use axum::body::Body;
use axum::http::{HeaderMap, Request, StatusCode};
use http_body_util::BodyExt;
use lofty::config::WriteOptions;
use lofty::prelude::*;
use lofty::tag::{Tag, TagType};
use qodi_server::{App, Config};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tempfile::TempDir;
use tower::ServiceExt;

const USER: &str = "admin";
const PASSWORD: &str = "secret-pass";

const ALPHA: &str = "Artist A/Album One/01 - Alpha.wav";
const BETA: &str = "Artist A/Album One/02 - Beta.wav";
const GAMMA: &str = "Artist B/Second/03 - Gamma.wav";
const LOOSE: &str = "Loose/untagged.wav";

fn short_hash(input: &str) -> String {
    hex::encode(Sha256::digest(input.as_bytes()))[..16].to_string()
}

/// Writes one second of a 16-bit mono PCM sine whose amplitude ramps up.
fn write_wav(path: &Path, seconds: u32) {
    let rate = 8000u32;
    let samples = rate * seconds;
    let mut data = Vec::with_capacity(samples as usize * 2);
    for i in 0..samples {
        let t = i as f32 / rate as f32;
        let amplitude = 0.1 + 0.8 * (i as f32 / samples as f32);
        let value = (amplitude * (2.0 * std::f32::consts::PI * 440.0 * t).sin() * i16::MAX as f32) as i16;
        data.extend_from_slice(&value.to_le_bytes());
    }
    let mut wav = Vec::new();
    wav.extend_from_slice(b"RIFF");
    wav.extend_from_slice(&(36 + data.len() as u32).to_le_bytes());
    wav.extend_from_slice(b"WAVEfmt ");
    wav.extend_from_slice(&16u32.to_le_bytes());
    wav.extend_from_slice(&1u16.to_le_bytes()); // PCM
    wav.extend_from_slice(&1u16.to_le_bytes()); // mono
    wav.extend_from_slice(&rate.to_le_bytes());
    wav.extend_from_slice(&(rate * 2).to_le_bytes());
    wav.extend_from_slice(&2u16.to_le_bytes());
    wav.extend_from_slice(&16u16.to_le_bytes());
    wav.extend_from_slice(b"data");
    wav.extend_from_slice(&(data.len() as u32).to_le_bytes());
    wav.extend_from_slice(&data);
    std::fs::create_dir_all(path.parent().unwrap()).unwrap();
    std::fs::write(path, wav).unwrap();
}

struct Tags<'a> {
    title: &'a str,
    artist: &'a str,
    album: &'a str,
    track: u32,
    year: &'a str,
}

fn tag_file(path: &Path, tags: Tags<'_>) {
    let mut tag = Tag::new(TagType::Id3v2);
    tag.set_title(tags.title.to_string());
    tag.set_artist(tags.artist.to_string());
    tag.set_album(tags.album.to_string());
    tag.set_track(tags.track);
    tag.insert_text(ItemKey::RecordingDate, tags.year.to_string());
    tag.save_to_path(path, WriteOptions::default()).unwrap();
}

struct Env {
    _dir: TempDir,
    music: PathBuf,
    app: App,
    token: String,
}

async fn setup() -> Env {
    let dir = tempfile::tempdir().unwrap();
    let music = dir.path().join("music");
    let data = dir.path().join("data");

    let alpha = music.join(ALPHA);
    write_wav(&alpha, 1);
    tag_file(&alpha, Tags { title: "Alpha Song", artist: "Artist A", album: "Album One", track: 1, year: "2020" });
    let beta = music.join(BETA);
    write_wav(&beta, 1);
    tag_file(&beta, Tags { title: "Beta", artist: "Artist A", album: "Album One", track: 2, year: "2020" });
    let gamma = music.join(GAMMA);
    write_wav(&gamma, 1);
    tag_file(&gamma, Tags { title: "Gamma José", artist: "Artist B", album: "Second", track: 1, year: "2021" });
    write_wav(&music.join(LOOSE), 1);
    std::fs::write(music.join("Artist A/Album One/cover.jpg"), [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]).unwrap();
    std::fs::write(
        music.join("Artist A/Album One/01 - Alpha.lrc"),
        "[ar:Artist A]\n[00:01.50]First line\n[00:00.25]Intro\n",
    )
    .unwrap();
    // Hidden Syncthing artefacts must be ignored.
    std::fs::create_dir_all(music.join(".stversions")).unwrap();
    write_wav(&music.join(".stversions/old.wav"), 1);

    let mut config = Config::new(&music, &data);
    config.web_dir = dir.path().join("no-web");
    config.admin_user = Some(USER.into());
    config.admin_password = Some(PASSWORD.into());
    config.scan_interval_secs = 0;
    let app = App::build(config).await.unwrap();
    app.state.scanner.scan_now().await.unwrap();

    let (status, body) = json_call(&app.router, "POST", "/api/v1/auth/login", None, Some(json!({"username": USER, "password": PASSWORD}))).await;
    assert_eq!(status, StatusCode::OK);
    let token = body["token"].as_str().unwrap().to_string();
    Env { _dir: dir, music, app, token }
}

async fn call(
    router: &Router,
    method: &str,
    uri: &str,
    token: Option<&str>,
    body: Option<Value>,
    headers: &[(&str, &str)],
) -> (StatusCode, HeaderMap, Vec<u8>) {
    let mut builder = Request::builder().method(method).uri(uri);
    if let Some(token) = token {
        builder = builder.header("authorization", format!("Bearer {token}"));
    }
    for (name, value) in headers {
        builder = builder.header(*name, *value);
    }
    let request = match body {
        Some(body) => builder.header("content-type", "application/json").body(Body::from(body.to_string())),
        None => builder.body(Body::empty()),
    }
    .unwrap();
    let response = router.clone().oneshot(request).await.unwrap();
    let status = response.status();
    let headers = response.headers().clone();
    let bytes = response.into_body().collect().await.unwrap().to_bytes().to_vec();
    (status, headers, bytes)
}

async fn json_call(router: &Router, method: &str, uri: &str, token: Option<&str>, body: Option<Value>) -> (StatusCode, Value) {
    let (status, _, bytes) = call(router, method, uri, token, body, &[]).await;
    let value = if bytes.is_empty() { Value::Null } else { serde_json::from_slice(&bytes).unwrap() };
    (status, value)
}

impl Env {
    async fn get(&self, uri: &str) -> (StatusCode, Value) {
        json_call(&self.app.router, "GET", uri, Some(&self.token), None).await
    }

    async fn send(&self, method: &str, uri: &str, body: Option<Value>) -> (StatusCode, Value) {
        json_call(&self.app.router, method, uri, Some(&self.token), body).await
    }
}

fn titles(items: &Value) -> Vec<&str> {
    items.as_array().unwrap().iter().map(|t| t["title"].as_str().unwrap()).collect()
}

fn assert_error(body: &Value, code: &str) {
    assert_eq!(body["error"]["code"], code, "body: {body}");
    assert!(body["error"]["message"].is_string());
}

fn has_ffmpeg() -> bool {
    std::process::Command::new("ffmpeg").arg("-version").output().is_ok_and(|o| o.status.success())
}

#[tokio::test]
async fn auth_flow() {
    let env = setup().await;
    let router = &env.app.router;

    let (status, body) = json_call(router, "GET", "/api/v1/health", None, None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body, json!({"status": "ok", "version": "0.1.0"}));

    let (status, body) = json_call(router, "GET", "/api/v1/tracks", None, None).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_error(&body, "unauthorized");

    let (status, body) = json_call(router, "GET", "/api/v1/me", Some("not-a-jwt"), None).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_error(&body, "unauthorized");

    for creds in [json!({"username": USER, "password": "wrong"}), json!({"username": "ghost", "password": PASSWORD})] {
        let (status, body) = json_call(router, "POST", "/api/v1/auth/login", None, Some(creds)).await;
        assert_eq!(status, StatusCode::UNAUTHORIZED);
        assert_error(&body, "invalid_credentials");
    }

    let (status, body) = json_call(router, "POST", "/api/v1/auth/login", None, Some(json!({"username": USER}))).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "bad_request");

    let (status, body) =
        json_call(router, "POST", "/api/v1/auth/login", None, Some(json!({"username": USER, "password": PASSWORD}))).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["user"]["username"], USER);
    let user_id = body["user"]["id"].as_str().unwrap().to_string();
    assert!(body["token"].is_string());

    let (status, me) = env.get("/api/v1/me").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(me, json!({"id": user_id, "username": USER}));

    let (status, me) = json_call(router, "GET", &format!("/api/v1/me?token={}", env.token), None, None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(me["username"], USER);

    let (status, body) = env.get("/api/v1/nope").await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_error(&body, "not_found");
}

#[tokio::test]
async fn library_listing_search_and_ids() {
    let env = setup().await;

    let (status, body) = env.get("/api/v1/tracks").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["total"], 4);
    assert_eq!(titles(&body["items"]), vec!["Alpha Song", "Beta", "Gamma José", "untagged"]);

    let alpha = &body["items"][0];
    assert_eq!(alpha["id"], short_hash(ALPHA));
    assert_eq!(alpha["artist_id"], short_hash("artist a"));
    assert_eq!(alpha["album_id"], short_hash("artist a\u{0}album one"));
    assert_eq!(alpha["album_artist"], "Artist A");
    assert_eq!(alpha["track_number"], 1);
    assert_eq!(alpha["year"], 2020);
    assert_eq!(alpha["format"], "wav");
    assert_eq!(alpha["has_cover"], true);
    assert_eq!(alpha["has_lyrics"], true);
    assert_eq!(alpha["favorite"], false);
    assert!((900..=1100).contains(&alpha["duration_ms"].as_i64().unwrap()));
    assert!(alpha["size_bytes"].as_i64().unwrap() > 16000);
    assert!(alpha["updated_at"].as_str().unwrap().ends_with('Z'));

    let loose = &body["items"][3];
    assert_eq!(loose["artist"], "Unknown Artist");
    assert_eq!(loose["album"], "Loose");
    assert_eq!(loose["track_number"], Value::Null);
    assert_eq!(loose["has_cover"], false);

    let (_, body) = env.get("/api/v1/tracks?q=JOS%C3%89").await;
    assert_eq!(titles(&body["items"]), vec!["Gamma José"]);
    let (_, body) = env.get("/api/v1/tracks?q=album%20one").await;
    assert_eq!(body["total"], 2);
    let (_, body) = env.get(&format!("/api/v1/tracks?artist_id={}", short_hash("artist b"))).await;
    assert_eq!(titles(&body["items"]), vec!["Gamma José"]);
    let (_, body) = env.get("/api/v1/tracks?limit=1&offset=1").await;
    assert_eq!(titles(&body["items"]), vec!["Beta"]);
    assert_eq!(body["total"], 4);
    let (status, body) = env.get("/api/v1/tracks?limit=-1").await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "bad_request");

    let (status, track) = env.get(&format!("/api/v1/tracks/{}", short_hash(GAMMA))).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(track["title"], "Gamma José");
    let (status, body) = env.get("/api/v1/tracks/0000000000000000").await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_error(&body, "not_found");

    let (_, albums) = env.get("/api/v1/albums").await;
    assert_eq!(albums["total"], 3);
    let album = &albums["items"][0];
    assert_eq!(album["title"], "Album One");
    assert_eq!(album["artist"], "Artist A");
    assert_eq!(album["artist_id"], short_hash("artist a"));
    assert_eq!(album["year"], 2020);
    assert_eq!(album["track_count"], 2);
    assert_eq!(album["cover_track_id"], short_hash(ALPHA));
    assert_eq!(albums["items"][2]["cover_track_id"], Value::Null);

    let (_, filtered) = env.get(&format!("/api/v1/albums?artist_id={}", short_hash("artist b"))).await;
    assert_eq!(filtered["total"], 1);
    assert_eq!(filtered["items"][0]["title"], "Second");

    let (status, detail) = env.get(&format!("/api/v1/albums/{}", short_hash("artist a\u{0}album one"))).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(detail["album"]["track_count"], 2);
    assert_eq!(titles(&detail["tracks"]), vec!["Alpha Song", "Beta"]);

    let (_, artists) = env.get("/api/v1/artists").await;
    assert_eq!(artists["total"], 3);
    let names: Vec<_> = artists["items"].as_array().unwrap().iter().map(|a| a["name"].as_str().unwrap()).collect();
    assert_eq!(names, vec!["Artist A", "Artist B", "Unknown Artist"]);
    assert_eq!(artists["items"][0]["album_count"], 1);
    assert_eq!(artists["items"][0]["track_count"], 2);
    assert_eq!(artists["items"][0]["id"], short_hash("artist a"));

    // Rescanning keeps ids stable and changes nothing.
    let report = env.app.state.scanner.scan_now().await.unwrap();
    assert_eq!(report.unchanged, 4);
    assert_eq!(report.upserted, 0);
    let (_, again) = env.get("/api/v1/tracks").await;
    assert_eq!(again["items"][0]["id"], short_hash(ALPHA));

    let (status, body) = env.send("POST", "/api/v1/library/scan", None).await;
    assert_eq!(status, StatusCode::ACCEPTED);
    assert_eq!(body, json!({"status": "scanning"}));
}

#[tokio::test]
async fn stream_original_with_range() {
    let env = setup().await;
    let id = short_hash(ALPHA);
    let size = std::fs::metadata(env.music.join(ALPHA)).unwrap().len();
    let uri = format!("/api/v1/tracks/{id}/stream");

    let (status, headers, body) = call(&env.app.router, "GET", &uri, Some(&env.token), None, &[]).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(headers["content-type"], "audio/wav");
    assert_eq!(headers["accept-ranges"], "bytes");
    assert_eq!(body.len() as u64, size);

    let (status, headers, body) =
        call(&env.app.router, "GET", &uri, Some(&env.token), None, &[("range", "bytes=0-99")]).await;
    assert_eq!(status, StatusCode::PARTIAL_CONTENT);
    assert_eq!(headers["content-range"], format!("bytes 0-99/{size}").as_str());
    assert_eq!(body.len(), 100);
    assert_eq!(&body[..4], b"RIFF");

    // Query-string token, as used by <audio> on web.
    let (status, _, _) = call(&env.app.router, "GET", &format!("{uri}?token={}", env.token), None, None, &[]).await;
    assert_eq!(status, StatusCode::OK);

    let (status, body) = env.get(&format!("{uri}?format=mp3")).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "bad_request");
    let (status, body) = env.get(&format!("{uri}?format=opus&bitrate=100")).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "bad_request");
}

#[tokio::test]
async fn stream_opus_transcode() {
    if !has_ffmpeg() {
        eprintln!("ffmpeg not found; skipping opus test");
        return;
    }
    let env = setup().await;
    let id = short_hash(ALPHA);
    let uri = format!("/api/v1/tracks/{id}/stream?format=opus&bitrate=64");
    let (status, headers, body) = call(&env.app.router, "GET", &uri, Some(&env.token), None, &[]).await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&body));
    assert_eq!(headers["content-type"], "audio/ogg");
    assert_eq!(&body[..4], b"OggS");
    let cached = env.app.state.config.data_dir.join(format!("cache/opus/{id}-64.ogg"));
    assert_eq!(std::fs::metadata(&cached).unwrap().len() as usize, body.len());

    let (status, headers, part) = call(&env.app.router, "GET", &uri, Some(&env.token), None, &[("range", "bytes=0-9")]).await;
    assert_eq!(status, StatusCode::PARTIAL_CONTENT);
    assert_eq!(headers["content-range"], format!("bytes 0-9/{}", body.len()).as_str());
    assert_eq!(part, body[..10]);
}

#[tokio::test]
async fn cover_lyrics_and_waveform() {
    let env = setup().await;
    let alpha = short_hash(ALPHA);
    let gamma = short_hash(GAMMA);

    let (status, headers, body) =
        call(&env.app.router, "GET", &format!("/api/v1/tracks/{alpha}/cover"), Some(&env.token), None, &[]).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(headers["content-type"], "image/jpeg");
    assert_eq!(body, vec![0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

    let (status, body) = env.get(&format!("/api/v1/tracks/{gamma}/cover")).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_error(&body, "not_found");

    let (status, lyrics) = env.get(&format!("/api/v1/tracks/{alpha}/lyrics")).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        lyrics,
        json!({"synced": true, "lines": [
            {"time_ms": 250, "text": "Intro"},
            {"time_ms": 1500, "text": "First line"}
        ]})
    );
    let (status, body) = env.get(&format!("/api/v1/tracks/{gamma}/lyrics")).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_error(&body, "not_found");

    let (status, waveform) = env.get(&format!("/api/v1/tracks/{alpha}/waveform")).await;
    assert_eq!(status, StatusCode::OK);
    let peaks = waveform["peaks"].as_array().unwrap();
    assert_eq!(peaks.len(), 120);
    assert!(peaks.iter().all(|p| (0.0..=1.0).contains(&p.as_f64().unwrap())));
    assert!(peaks.iter().any(|p| p.as_f64().unwrap() > 0.99));
    // Amplitude ramps up, so the start is quieter than the end.
    assert!(peaks[0].as_f64().unwrap() < peaks[119].as_f64().unwrap());
    let (_, cached) = env.get(&format!("/api/v1/tracks/{alpha}/waveform")).await;
    assert_eq!(cached, waveform);
}

#[tokio::test]
async fn playlists_crud_and_reorder() {
    let env = setup().await;
    let (alpha, beta) = (short_hash(ALPHA), short_hash(BETA));

    let (status, created) = env.send("POST", "/api/v1/playlists", Some(json!({"name": "Night drive"}))).await;
    assert_eq!(status, StatusCode::CREATED);
    assert_eq!(created["name"], "Night drive");
    assert_eq!(created["track_count"], 0);
    assert_eq!(created["duration_ms"], 0);
    assert_eq!(created["cover_track_id"], Value::Null);
    let id = created["id"].as_str().unwrap().to_string();
    let uri = format!("/api/v1/playlists/{id}");

    let (status, body) = env.send("POST", "/api/v1/playlists", Some(json!({"name": "  "}))).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "bad_request");

    let (status, updated) = env.send("PATCH", &uri, Some(json!({"track_ids": [beta, alpha]}))).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(updated["track_count"], 2);
    assert_eq!(updated["cover_track_id"], beta);
    assert!(updated["duration_ms"].as_i64().unwrap() > 1800);

    let (_, detail) = env.get(&uri).await;
    assert_eq!(detail["playlist"]["id"], id);
    assert_eq!(titles(&detail["tracks"]), vec!["Beta", "Alpha Song"]);

    let (_, reordered) = env.send("PATCH", &uri, Some(json!({"track_ids": [alpha, beta], "name": "Renamed"}))).await;
    assert_eq!(reordered["name"], "Renamed");
    let (_, detail) = env.get(&uri).await;
    assert_eq!(titles(&detail["tracks"]), vec!["Alpha Song", "Beta"]);

    let (status, body) = env.send("PATCH", &uri, Some(json!({"track_ids": ["ffffffffffffffff"]}))).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "bad_request");

    let (_, second) = env.send("POST", "/api/v1/playlists", Some(json!({"name": "Second"}))).await;
    let (_, list) = env.get("/api/v1/playlists").await;
    assert_eq!(list["total"], 2);
    assert_eq!(list["items"][0]["id"], second["id"]); // updated_at desc

    let (status, body) = env.send("DELETE", &uri, None).await;
    assert_eq!(status, StatusCode::NO_CONTENT);
    assert_eq!(body, Value::Null);
    let (status, body) = env.get(&uri).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_error(&body, "not_found");
    let (status, _) = env.send("DELETE", &uri, None).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn favorites_are_idempotent() {
    let env = setup().await;
    let (alpha, gamma) = (short_hash(ALPHA), short_hash(GAMMA));

    for id in [&alpha, &alpha, &gamma] {
        let (status, body) = env.send("PUT", &format!("/api/v1/favorites/{id}"), None).await;
        assert_eq!(status, StatusCode::NO_CONTENT);
        assert_eq!(body, Value::Null);
    }
    let (_, favorites) = env.get("/api/v1/favorites").await;
    assert_eq!(favorites["total"], 2);
    assert_eq!(titles(&favorites["items"]), vec!["Gamma José", "Alpha Song"]);
    assert!(favorites["items"].as_array().unwrap().iter().all(|t| t["favorite"] == true));

    let (_, track) = env.get(&format!("/api/v1/tracks/{alpha}")).await;
    assert_eq!(track["favorite"], true);

    for _ in 0..2 {
        let (status, _) = env.send("DELETE", &format!("/api/v1/favorites/{alpha}"), None).await;
        assert_eq!(status, StatusCode::NO_CONTENT);
    }
    let (_, track) = env.get(&format!("/api/v1/tracks/{alpha}")).await;
    assert_eq!(track["favorite"], false);
    let (_, favorites) = env.get("/api/v1/favorites").await;
    assert_eq!(favorites["total"], 1);

    let (status, body) = env.send("PUT", "/api/v1/favorites/ffffffffffffffff", None).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_error(&body, "not_found");
}

#[tokio::test]
async fn plays_dedupe_and_stats() {
    let env = setup().await;
    let (alpha, gamma) = (short_hash(ALPHA), short_hash(GAMMA));
    let played_at = (chrono::Utc::now() - chrono::Duration::hours(1)).to_rfc3339_opts(chrono::SecondsFormat::Secs, true);
    let date = &played_at[..10];
    let first = "6f1c2b9e-0c55-4d1e-9a7a-6f8d2a3b4c5d";
    let plays = json!({"plays": [
        {"client_id": first, "track_id": alpha, "played_at": played_at, "listened_ms": 1000},
        {"client_id": first, "track_id": alpha, "played_at": played_at, "listened_ms": 1000},
        {"client_id": "0a7d8a3e-2c1b-4f6e-8d9c-1b2a3c4d5e6f", "track_id": alpha, "played_at": played_at, "listened_ms": 500},
        {"client_id": "9b8c7d6e-5f4a-4b3c-8d2e-1f0a9b8c7d6e", "track_id": gamma, "played_at": played_at, "listened_ms": 250}
    ]});
    let (status, body) = env.send("POST", "/api/v1/plays", Some(plays.clone())).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body, json!({"accepted": 3}));
    let (_, body) = env.send("POST", "/api/v1/plays", Some(plays)).await;
    assert_eq!(body, json!({"accepted": 0}));

    let bad = json!({"plays": [{"client_id": "nope", "track_id": alpha, "played_at": played_at, "listened_ms": 1}]});
    let (status, body) = env.send("POST", "/api/v1/plays", Some(bad)).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "bad_request");

    let (status, summary) = env.get("/api/v1/stats/summary").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(summary["range"], "30d");
    assert_eq!(summary["total_plays"], 3);
    assert_eq!(summary["total_listen_ms"], 1750);
    assert_eq!(summary["unique_tracks"], 2);
    assert_eq!(summary["top_tracks"][0]["track"]["id"], alpha);
    assert_eq!(summary["top_tracks"][0]["plays"], 2);
    assert_eq!(summary["top_tracks"].as_array().unwrap().len(), 2);
    assert_eq!(
        summary["top_artists"][0],
        json!({"artist_id": short_hash("artist a"), "name": "Artist A", "plays": 2})
    );
    assert_eq!(summary["daily"], json!([{"date": date, "listen_ms": 1750}]));

    let (_, all) = env.get("/api/v1/stats/summary?range=all").await;
    assert_eq!(all["range"], "all");
    assert_eq!(all["total_plays"], 3);
    let (status, body) = env.get("/api/v1/stats/summary?range=1y").await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "bad_request");
}

#[tokio::test]
async fn library_changes_report_tombstones() {
    let env = setup().await;
    let beta = short_hash(BETA);

    let (status, snapshot) = env.get("/api/v1/library/changes").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(snapshot["tracks"].as_array().unwrap().len(), 4);
    assert_eq!(snapshot["removed_track_ids"], json!([]));
    assert!(snapshot["server_time"].as_str().unwrap().ends_with('Z'));

    // server_time has second precision; make sure it is strictly after the first scan.
    tokio::time::sleep(std::time::Duration::from_millis(1100)).await;
    let (_, marker) = env.get("/api/v1/library/changes").await;
    let since = marker["server_time"].as_str().unwrap().to_string();

    std::fs::remove_file(env.music.join(BETA)).unwrap();
    let report = env.app.state.scanner.scan_now().await.unwrap();
    assert_eq!(report.removed, 1);

    let (status, delta) = env.get(&format!("/api/v1/library/changes?since={since}")).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(delta["tracks"], json!([]));
    assert_eq!(delta["removed_track_ids"], json!([beta]));

    let (_, everything) = env.get("/api/v1/library/changes?since=2000-01-01T00:00:00Z").await;
    assert_eq!(everything["tracks"].as_array().unwrap().len(), 3);
    assert_eq!(everything["removed_track_ids"], json!([beta]));

    let (status, body) = env.get("/api/v1/library/changes?since=yesterday").await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_error(&body, "bad_request");

    let (_, tracks) = env.get("/api/v1/tracks").await;
    assert_eq!(tracks["total"], 3);
}

#[tokio::test]
async fn serves_web_build_with_spa_fallback() {
    let env = setup().await;
    let (status, _, _) = call(&env.app.router, "GET", "/", None, None, &[]).await;
    assert_eq!(status, StatusCode::NOT_FOUND); // no web dir configured

    let dir = tempfile::tempdir().unwrap();
    let web = dir.path().join("web");
    std::fs::create_dir_all(&web).unwrap();
    std::fs::write(web.join("index.html"), "<html>qodi</html>").unwrap();
    std::fs::write(web.join("main.js"), "console.log(1)").unwrap();
    let mut config = Config::new(dir.path().join("music"), dir.path().join("data"));
    std::fs::create_dir_all(&config.music_dir).unwrap();
    config.web_dir = web;
    let app = App::build(config).await.unwrap();

    let (status, _, body) = call(&app.router, "GET", "/main.js", None, None, &[]).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body, b"console.log(1)");
    let (status, _, body) = call(&app.router, "GET", "/library/albums", None, None, &[]).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body, b"<html>qodi</html>");
    let (status, _, _) = call(&app.router, "GET", "/api/v2/whatever", None, None, &[]).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
}
