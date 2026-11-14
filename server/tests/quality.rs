//! Per-track audio quality fields and the upgrade from a database created by `0001_init.sql`.

mod common;

use std::path::Path;
use std::time::UNIX_EPOCH;

use axum::http::StatusCode;
use qodi_server::auth::hash_password;
use qodi_server::{App, Config};
use serde_json::{Value, json};
use sqlx::SqlitePool;
use sqlx::migrate::Migrator;

use common::*;

#[tokio::test]
async fn wav_tracks_report_lossless_quality() {
    let env = setup().await;
    let (status, track) = env.get(&format!("/api/v1/tracks/{}", short_hash(ALPHA))).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(track["format"], "wav");
    assert_eq!(track["sample_rate_hz"], 8000);
    assert_eq!(track["bit_depth"], 16);
    assert_eq!(track["channels"], 1);
    assert_eq!(track["lossless"], true);
    assert_eq!(track["bitrate_kbps"], 128);

    // Every endpoint that returns tracks carries the fields.
    let (_, list) = env.get("/api/v1/tracks").await;
    assert!(list["items"].as_array().unwrap().iter().all(|t| t["lossless"] == true && t["sample_rate_hz"] == 8000));
    let (_, changes) = env.get("/api/v1/library/changes").await;
    assert_eq!(changes["tracks"][0]["bit_depth"], 16);
}

fn ffmpeg(args: &[&str], out: &Path) {
    std::fs::create_dir_all(out.parent().unwrap()).unwrap();
    let status = std::process::Command::new("ffmpeg")
        .args(["-y", "-loglevel", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=1"])
        .args(args)
        .arg(out)
        .status()
        .unwrap();
    assert!(status.success(), "ffmpeg failed for {}", out.display());
}

#[tokio::test]
async fn generated_formats_report_quality() {
    if !has_ffmpeg() {
        eprintln!("ffmpeg not found; skipping generated formats test");
        return;
    }
    let env = setup().await;
    let cases: [(&str, &[&str]); 5] = [
        ("Gen/lossy.mp3", &["-ac", "2", "-ar", "44100", "-b:a", "128k"]),
        ("Gen/lossy.opus", &["-ac", "2", "-ar", "48000", "-c:a", "libopus", "-b:a", "96k"]),
        ("Gen/lossy.m4a", &["-ac", "2", "-ar", "44100", "-c:a", "aac", "-b:a", "128k"]),
        ("Gen/apple-lossless.m4a", &["-ac", "2", "-ar", "48000", "-c:a", "alac", "-sample_fmt", "s16p"]),
        ("Gen/free.flac", &["-ac", "1", "-ar", "96000", "-c:a", "flac", "-sample_fmt", "s32"]),
    ];
    for (path, args) in &cases {
        ffmpeg(args, &env.music.join(path));
    }
    let report = env.app.state.scanner.scan_now().await.unwrap();
    assert_eq!(report.upserted, cases.len());

    let env = &env;
    let track = |path: &str| {
        let uri = format!("/api/v1/tracks/{}", short_hash(path));
        async move { env.get(&uri).await.1 }
    };
    for (path, rate) in [("Gen/lossy.mp3", 44100), ("Gen/lossy.opus", 48000), ("Gen/lossy.m4a", 44100)] {
        let t = track(path).await;
        assert_eq!(t["lossless"], false, "{path}: {t}");
        assert_eq!(t["bit_depth"], Value::Null, "{path}: {t}");
        assert_eq!(t["sample_rate_hz"], rate, "{path}: {t}");
        assert_eq!(t["channels"], 2, "{path}: {t}");
        assert!(t["bitrate_kbps"].as_i64().unwrap() > 0, "{path}: {t}");
    }
    let alac = track("Gen/apple-lossless.m4a").await;
    assert_eq!(alac["format"], "m4a");
    assert_eq!(alac["lossless"], true, "{alac}");
    assert_eq!(alac["bit_depth"], 16, "{alac}");
    assert_eq!(alac["sample_rate_hz"], 48000, "{alac}");
    let flac = track("Gen/free.flac").await;
    assert_eq!(flac["lossless"], true, "{flac}");
    assert_eq!(flac["sample_rate_hz"], 96000, "{flac}");
    assert_eq!(flac["channels"], 1, "{flac}");
    assert_eq!(flac["bit_depth"], 24, "{flac}");
}

fn mtime_ms(path: &Path) -> i64 {
    std::fs::metadata(path).unwrap().modified().unwrap().duration_since(UNIX_EPOCH).unwrap().as_millis() as i64
}

/// Creates `{data}/qodi.db` with only the first migration applied, the way the
/// previous release left it.
async fn database_from_first_release(data: &Path, migrations: &Path) -> SqlitePool {
    std::fs::create_dir_all(data).unwrap();
    std::fs::create_dir_all(migrations).unwrap();
    std::fs::copy(
        Path::new(env!("CARGO_MANIFEST_DIR")).join("migrations/0001_init.sql"),
        migrations.join("0001_init.sql"),
    )
    .unwrap();
    let url = format!("sqlite://{}?mode=rwc", data.join("qodi.db").display());
    let pool = SqlitePool::connect(&url).await.unwrap();
    Migrator::new(migrations).await.unwrap().run(&pool).await.unwrap();
    pool
}

#[tokio::test]
async fn upgrade_from_first_release_keeps_data_and_backfills_quality() {
    let dir = tempfile::tempdir().unwrap();
    let music = dir.path().join("music");
    let data = dir.path().join("data");
    let alpha_path = music.join(ALPHA);
    write_wav(&alpha_path, 1);
    let alpha = short_hash(ALPHA);

    let pool = database_from_first_release(&data, &dir.path().join("old-migrations")).await;
    let hash = hash_password(PASSWORD).unwrap();
    let member_hash = hash_password("member-pass").unwrap();
    let statements: Vec<(&str, Vec<Value>)> = vec![
        ("INSERT INTO users VALUES ('u-admin', ?1, ?2, 1000)", vec![json!(USER), json!(hash)]),
        ("INSERT INTO users VALUES ('u-member', 'member', ?1, 2000)", vec![json!(member_hash)]),
        (
            "INSERT INTO tracks (id, path, title, artist, artist_id, album, album_id, album_artist, album_artist_id, \
             track_number, disc_number, year, genre, duration_ms, format, bitrate_kbps, size_bytes, mtime_ms, \
             has_embedded_cover, has_embedded_lyrics, has_cover, has_lyrics, search_text, updated_at) \
             VALUES (?1, ?2, '01 - Alpha', 'Unknown Artist', ?3, 'Album One', ?4, 'Unknown Artist', ?3, \
             NULL, NULL, NULL, NULL, 1000, 'wav', 128, ?5, ?6, 0, 0, 0, 0, 'x', 1000)",
            vec![
                json!(alpha),
                json!(ALPHA),
                json!(short_hash("unknown artist")),
                json!(short_hash("unknown artist\u{0}album one")),
                json!(std::fs::metadata(&alpha_path).unwrap().len()),
                json!(mtime_ms(&alpha_path)),
            ],
        ),
        ("INSERT INTO favorites VALUES ('u-admin', ?1, 3000)", vec![json!(alpha)]),
        ("INSERT INTO playlists VALUES ('p1', 'u-admin', 'Old list', 3000, 3000)", vec![]),
        ("INSERT INTO playlist_tracks VALUES ('p1', 0, ?1)", vec![json!(alpha)]),
        ("INSERT INTO plays VALUES ('6f1c2b9e-0c55-4d1e-9a7a-6f8d2a3b4c5d', 'u-member', ?1, 4000, 1000)", vec![json!(alpha)]),
    ];
    for (sql, args) in statements {
        let mut query = sqlx::query(sql);
        for arg in args {
            query = match arg {
                Value::String(s) => query.bind(s),
                Value::Number(n) => query.bind(n.as_i64().unwrap()),
                other => panic!("unsupported bind {other}"),
            };
        }
        query.execute(&pool).await.unwrap();
    }
    pool.close().await;

    let mut config = Config::new(&music, &data);
    config.web_dir = dir.path().join("no-web");
    config.scan_interval_secs = 0;
    config.admin_user = Some(USER.into());
    config.admin_password = Some("not-the-stored-password".into());
    let app = App::build(config).await.unwrap();

    // Unchanged files (same size and mtime) are re-read once to fill the quality fields.
    let report = app.state.scanner.scan_now().await.unwrap();
    assert_eq!((report.upserted, report.unchanged, report.removed), (1, 0, 0));
    let again = app.state.scanner.scan_now().await.unwrap();
    assert_eq!((again.upserted, again.unchanged), (0, 1));

    let router = &app.router;
    let (status, login) =
        json_call(router, "POST", "/api/v1/auth/login", None, Some(json!({"username": USER, "password": PASSWORD}))).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(login["user"], json!({"id": "u-admin", "username": USER, "is_admin": true}));
    let token = login["token"].as_str().unwrap();
    let (status, member) =
        json_call(router, "POST", "/api/v1/auth/login", None, Some(json!({"username": "member", "password": "member-pass"})))
            .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(member["user"]["is_admin"], false);

    let (_, track) = json_call(router, "GET", &format!("/api/v1/tracks/{alpha}"), Some(token), None).await;
    assert_eq!(track["sample_rate_hz"], 8000);
    assert_eq!(track["bit_depth"], 16);
    assert_eq!(track["channels"], 1);
    assert_eq!(track["lossless"], true);
    assert_eq!(track["favorite"], true);
    assert_ne!(track["updated_at"], "1970-01-01T00:00:01Z");
    let (_, changes) =
        json_call(router, "GET", "/api/v1/library/changes?since=2000-01-01T00:00:00Z", Some(token), None).await;
    assert_eq!(changes["tracks"][0]["id"], alpha);
    assert_eq!(changes["tracks"][0]["lossless"], true);

    let (_, playlists) = json_call(router, "GET", "/api/v1/playlists", Some(token), None).await;
    assert_eq!(playlists["total"], 1);
    assert_eq!(playlists["items"][0]["name"], "Old list");
    assert_eq!(playlists["items"][0]["track_count"], 1);
    let (_, users) = json_call(router, "GET", "/api/v1/admin/users", Some(token), None).await;
    assert_eq!(users["total"], 2);
    let member_token = member["token"].as_str().unwrap();
    let (_, stats) = json_call(router, "GET", "/api/v1/stats/summary?range=all", Some(member_token), None).await;
    assert_eq!(stats["total_plays"], 1);
}

/// The first release shipped a `0001_init.sql` whose `plays` table had a global
/// `client_id` primary key; that file was later edited in place. A database created
/// by that release must still start, keep its plays, and dedupe plays per user.
#[tokio::test]
async fn upgrade_from_database_with_original_first_migration() {
    let dir = tempfile::tempdir().unwrap();
    let music = dir.path().join("music");
    let data = dir.path().join("data");
    write_wav(&music.join(ALPHA), 1);
    let alpha = short_hash(ALPHA);

    let migrations = dir.path().join("old-migrations");
    std::fs::create_dir_all(&migrations).unwrap();
    std::fs::copy(
        Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/0001_init_first_release.sql"),
        migrations.join("0001_init.sql"),
    )
    .unwrap();
    std::fs::create_dir_all(&data).unwrap();
    let pool = SqlitePool::connect(&format!("sqlite://{}?mode=rwc", data.join("qodi.db").display())).await.unwrap();
    Migrator::new(migrations.as_path()).await.unwrap().run(&pool).await.unwrap();
    sqlx::query("INSERT INTO users VALUES ('u-admin', ?1, ?2, 1000)")
        .bind(USER)
        .bind(hash_password(PASSWORD).unwrap())
        .execute(&pool)
        .await
        .unwrap();
    sqlx::query("INSERT INTO plays VALUES ('6f1c2b9e-0c55-4d1e-9a7a-6f8d2a3b4c5d', 'u-admin', ?1, 4000, 1000)")
        .bind(&alpha)
        .execute(&pool)
        .await
        .unwrap();
    pool.close().await;

    let mut config = Config::new(&music, &data);
    config.web_dir = dir.path().join("no-web");
    config.scan_interval_secs = 0;
    config.admin_user = Some(USER.into());
    let app = App::build(config).await.expect("database from the first release must open");
    app.state.scanner.scan_now().await.unwrap();

    let router = &app.router;
    let (status, login) =
        json_call(router, "POST", "/api/v1/auth/login", None, Some(json!({"username": USER, "password": PASSWORD}))).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(login["user"]["is_admin"], true);
    let token = login["token"].as_str().unwrap();
    let (_, stats) = json_call(router, "GET", "/api/v1/stats/summary?range=all", Some(token), None).await;
    assert_eq!(stats["total_plays"], 1);

    // The same client_id from another user is a different play.
    let invite = json_call(router, "POST", "/api/v1/admin/invites", Some(token), Some(json!({}))).await.1;
    let (status, member) = json_call(
        router,
        "POST",
        "/api/v1/auth/register",
        None,
        Some(json!({"invite_code": invite["code"], "username": "member", "password": "member-pass"})),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED);
    let play = json!({"plays": [{"client_id": "6f1c2b9e-0c55-4d1e-9a7a-6f8d2a3b4c5d", "track_id": alpha,
        "played_at": "2026-11-13T10:00:00Z", "listened_ms": 1000}]});
    let (_, accepted) = json_call(router, "POST", "/api/v1/plays", member["token"].as_str(), Some(play)).await;
    assert_eq!(accepted, json!({"accepted": 1}));

    // Reopening the repaired database works too.
    drop(app);
    let mut config = Config::new(&music, &data);
    config.web_dir = dir.path().join("no-web");
    App::build(config).await.expect("repaired database reopens");
}
