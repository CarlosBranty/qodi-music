//! Shared harness for the HTTP integration tests.
#![allow(dead_code)]

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

pub const USER: &str = "admin";
pub const PASSWORD: &str = "secret-pass";

pub const ALPHA: &str = "Artist A/Album One/01 - Alpha.wav";
pub const BETA: &str = "Artist A/Album One/02 - Beta.wav";
pub const GAMMA: &str = "Artist B/Second/03 - Gamma.wav";
pub const LOOSE: &str = "Loose/untagged.wav";

pub fn short_hash(input: &str) -> String {
    hex::encode(Sha256::digest(input.as_bytes()))[..16].to_string()
}

/// Writes one second of a 16-bit mono PCM sine whose amplitude ramps up.
pub fn write_wav(path: &Path, seconds: u32) {
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

pub struct Tags<'a> {
    pub title: &'a str,
    pub artist: &'a str,
    pub album: &'a str,
    pub track: u32,
    pub year: &'a str,
}

pub fn tag_file(path: &Path, tags: Tags<'_>) {
    let mut tag = Tag::new(TagType::Id3v2);
    tag.set_title(tags.title.to_string());
    tag.set_artist(tags.artist.to_string());
    tag.set_album(tags.album.to_string());
    tag.set_track(tags.track);
    tag.insert_text(ItemKey::RecordingDate, tags.year.to_string());
    tag.save_to_path(path, WriteOptions::default()).unwrap();
}

pub struct Env {
    pub _dir: TempDir,
    pub data: PathBuf,
    pub music: PathBuf,
    pub app: App,
    pub token: String,
}

pub async fn setup() -> Env {
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
    Env { _dir: dir, data, music, app, token }
}

pub async fn call(
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

pub async fn json_call(router: &Router, method: &str, uri: &str, token: Option<&str>, body: Option<Value>) -> (StatusCode, Value) {
    let (status, _, bytes) = call(router, method, uri, token, body, &[]).await;
    let value = if bytes.is_empty() { Value::Null } else { serde_json::from_slice(&bytes).unwrap() };
    (status, value)
}

impl Env {
    pub async fn get(&self, uri: &str) -> (StatusCode, Value) {
        json_call(&self.app.router, "GET", uri, Some(&self.token), None).await
    }

    pub async fn send(&self, method: &str, uri: &str, body: Option<Value>) -> (StatusCode, Value) {
        json_call(&self.app.router, method, uri, Some(&self.token), body).await
    }
}

pub fn titles(items: &Value) -> Vec<&str> {
    items.as_array().unwrap().iter().map(|t| t["title"].as_str().unwrap()).collect()
}

pub fn assert_error(body: &Value, code: &str) {
    assert_eq!(body["error"]["code"], code, "body: {body}");
    assert!(body["error"]["message"].is_string());
}

pub fn has_ffmpeg() -> bool {
    std::process::Command::new("ffmpeg").arg("-version").output().is_ok_and(|o| o.status.success())
}
