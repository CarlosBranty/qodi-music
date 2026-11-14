//! Android self-update: the public manifest and APK downloads from `QODI_DIST_DIR`.

mod common;

use std::path::Path;

use axum::http::StatusCode;
use qodi_server::{App, Config};
use serde_json::{Value, json};

use common::*;

const APK_MIME: &str = "application/vnd.android.package-archive";

async fn app_with_dist(root: &Path) -> App {
    let mut config = Config::new(root.join("music"), root.join("data"));
    std::fs::create_dir_all(&config.music_dir).unwrap();
    let web = root.join("web");
    std::fs::create_dir_all(&web).unwrap();
    std::fs::write(web.join("index.html"), "<html>qodi</html>").unwrap();
    config.web_dir = web;
    config.dist_dir = root.join("dist");
    config.scan_interval_secs = 0;
    App::build(config).await.unwrap()
}

fn latest(file: &str) -> Value {
    json!({"version_name": "0.2.0", "version_code": 57, "file": file, "sha256": "ab".repeat(32),
           "size_bytes": 4096, "published_at": "2026-11-14T10:00:00Z"})
}

#[tokio::test]
async fn manifest_is_404_until_published_and_startup_survives_missing_dist() {
    let dir = tempfile::tempdir().unwrap();
    let app = app_with_dist(dir.path()).await; // dist dir does not exist
    let (status, body) = json_call(&app.router, "GET", "/api/v1/app/android", None, None).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_error(&body, "not_found");

    let android = dir.path().join("dist/android");
    std::fs::create_dir_all(&android).unwrap();
    for invalid in ["not json".to_string(), json!({"version_name": "0.2.0"}).to_string(), latest("../secret.apk").to_string()] {
        std::fs::write(android.join("latest.json"), invalid.as_bytes()).unwrap();
        let (status, body) = json_call(&app.router, "GET", "/api/v1/app/android", None, None).await;
        assert_eq!(status, StatusCode::NOT_FOUND, "{invalid}");
        assert_error(&body, "not_found");
    }
}

#[tokio::test]
async fn manifest_and_download_are_public_with_range() {
    let dir = tempfile::tempdir().unwrap();
    let app = app_with_dist(dir.path()).await;
    let android = dir.path().join("dist/android");
    std::fs::create_dir_all(&android).unwrap();
    let apk: Vec<u8> = (0..4096u32).map(|i| (i % 251) as u8).collect();
    std::fs::write(android.join("qodi-music.apk"), &apk).unwrap();
    std::fs::write(android.join("latest.json"), latest("qodi-music.apk").to_string()).unwrap();

    let (status, body) = json_call(&app.router, "GET", "/api/v1/app/android", None, None).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        body,
        json!({"version_name": "0.2.0", "version_code": 57, "url": "/downloads/android/qodi-music.apk",
               "sha256": "ab".repeat(32), "size_bytes": 4096, "published_at": "2026-11-14T10:00:00Z"})
    );

    // Re-read on every request: a redeploy is visible without restarting.
    std::fs::write(android.join("latest.json"), json!({"version_name": "0.3.0", "version_code": 58,
        "file": "qodi-music-58.apk", "sha256": "cd", "size_bytes": 1, "published_at": "2026-11-15T10:00:00Z"}).to_string())
        .unwrap();
    let (_, body) = json_call(&app.router, "GET", "/api/v1/app/android", None, None).await;
    assert_eq!(body["version_code"], 58);
    assert_eq!(body["url"], "/downloads/android/qodi-music-58.apk");

    let uri = "/downloads/android/qodi-music.apk";
    let (status, headers, bytes) = call(&app.router, "GET", uri, None, None, &[]).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(headers["content-type"], APK_MIME);
    assert_eq!(headers["accept-ranges"], "bytes");
    assert_eq!(bytes, apk);

    let (status, headers, bytes) = call(&app.router, "GET", uri, None, None, &[("range", "bytes=100-199")]).await;
    assert_eq!(status, StatusCode::PARTIAL_CONTENT);
    assert_eq!(headers["content-range"], "bytes 100-199/4096");
    assert_eq!(headers["content-type"], APK_MIME);
    assert_eq!(bytes, apk[100..200]);

    let (status, _, _) = call(&app.router, "GET", "/downloads/android/missing.apk", None, None, &[]).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn downloads_reject_traversal_and_listing() {
    let dir = tempfile::tempdir().unwrap();
    let app = app_with_dist(dir.path()).await;
    let android = dir.path().join("dist/android");
    std::fs::create_dir_all(android.join("sub")).unwrap();
    std::fs::write(android.join("sub/inner.apk"), b"inner").unwrap();
    std::fs::write(dir.path().join("dist/secret.txt"), b"secret").unwrap();
    std::fs::write(dir.path().join("secret.txt"), b"secret").unwrap();

    for uri in [
        "/downloads/android/..%2fsecret.txt",
        "/downloads/android/..%2F..%2Fsecret.txt",
        "/downloads/android/%2e%2e%2fsecret.txt",
        "/downloads/android/..%5csecret.txt",
        "/downloads/android/sub%2finner.apk",
        "/downloads/android/..",
        "/downloads/android/sub",
        "/downloads/android/.hidden",
    ] {
        let (status, _, body) = call(&app.router, "GET", uri, None, None, &[]).await;
        assert_eq!(status, StatusCode::NOT_FOUND, "{uri}");
        assert_ne!(body, b"secret", "{uri}");
        assert_ne!(body, b"inner", "{uri}");
    }
    // No directory listing; the SPA fallback does not answer for the downloads tree either.
    for uri in ["/downloads/android/", "/downloads/android"] {
        let (status, _, body) = call(&app.router, "GET", uri, None, None, &[]).await;
        assert_eq!(status, StatusCode::NOT_FOUND, "{uri}");
        assert_ne!(body, b"<html>qodi</html>", "{uri}");
    }

    // Other non-/api paths still get the SPA.
    let (status, _, body) = call(&app.router, "GET", "/library/albums", None, None, &[]).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body, b"<html>qodi</html>");
}
