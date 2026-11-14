//! End-to-end tests through the public HTTP interface (`docs/api.md`).

mod common;

use axum::http::StatusCode;
use qodi_server::{App, Config};
use serde_json::{Value, json};

use common::*;


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
    assert_eq!(body["user"]["is_admin"], true);
    let user_id = body["user"]["id"].as_str().unwrap().to_string();
    assert!(body["token"].is_string());

    let (status, me) = env.get("/api/v1/me").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(me, json!({"id": user_id, "username": USER, "is_admin": true}));

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
async fn stream_flac_transcode_keeps_alac_lossless() {
    if !has_ffmpeg() {
        eprintln!("ffmpeg not found; skipping flac test");
        return;
    }
    let env = setup().await;
    // Apple Lossless as found in real libraries: Android (ExoPlayer) and browsers cannot decode it.
    const ALAC: &str = "Gen/apple-lossless.m4a";
    let source = env.music.join(ALAC);
    std::fs::create_dir_all(source.parent().unwrap()).unwrap();
    let status = std::process::Command::new("ffmpeg")
        .args(["-y", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=1"])
        .args(["-ac", "2", "-ar", "96000", "-c:a", "alac", "-sample_fmt", "s32p"])
        .arg(&source)
        .status()
        .unwrap();
    assert!(status.success());
    env.app.state.scanner.scan_now().await.unwrap();

    let id = short_hash(ALAC);
    let uri = format!("/api/v1/tracks/{id}/stream?format=flac");
    let (status, headers, body) = call(&env.app.router, "GET", &uri, Some(&env.token), None, &[]).await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&body));
    assert_eq!(headers["content-type"], "audio/flac");
    assert_eq!(headers["accept-ranges"], "bytes");
    assert_eq!(&body[..4], b"fLaC");
    let cached = env.app.state.config.data_dir.join(format!("cache/flac/{id}.flac"));
    assert_eq!(std::fs::metadata(&cached).unwrap().len() as usize, body.len());

    // Lossless: sample rate and bit depth survive the transcode.
    let probe = std::process::Command::new("ffprobe")
        .args(["-v", "error", "-select_streams", "a:0", "-show_entries", "stream=codec_name,sample_rate,bits_per_raw_sample"])
        .args(["-of", "csv=p=0"])
        .arg(&cached)
        .output()
        .unwrap();
    assert_eq!(String::from_utf8_lossy(&probe.stdout).trim(), "flac,96000,24");

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
