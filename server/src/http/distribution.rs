//! Public client distribution: the Android update manifest and APK downloads,
//! both served from `{QODI_DIST_DIR}/android/`.

use std::path::PathBuf;

use axum::Json;
use axum::extract::{Path, Request, State};
use axum::response::{IntoResponse, Response};
use serde::{Deserialize, Serialize};
use tower::ServiceExt;
use tower_http::services::ServeFile;

use super::error::{ApiError, ApiResult};
use crate::app::AppState;

const APK_MIME: &str = "application/vnd.android.package-archive";

/// `latest.json` as written by CI.
#[derive(Deserialize)]
struct LatestJson {
    version_name: String,
    version_code: i64,
    file: String,
    sha256: String,
    size_bytes: i64,
    published_at: String,
}

#[derive(Serialize)]
pub struct AndroidRelease {
    version_name: String,
    version_code: i64,
    url: String,
    sha256: String,
    size_bytes: i64,
    published_at: String,
}

fn android_dir(state: &AppState) -> PathBuf {
    state.config.dist_dir.join("android")
}

/// A single plain file name: `[A-Za-z0-9._-]+`, not starting with a dot. This rules
/// out `..`, separators (including percent-decoded ones) and hidden files.
fn safe_file_name(name: &str) -> bool {
    !name.is_empty()
        && !name.starts_with('.')
        && name.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-'))
}

/// Re-read on every request so a redeploy is visible immediately.
pub async fn android_manifest(State(state): State<AppState>) -> ApiResult<Json<AndroidRelease>> {
    let path = android_dir(&state).join("latest.json");
    let not_published = || ApiError::not_found("android release");
    let raw = tokio::fs::read(&path).await.map_err(|_| not_published())?;
    let latest: LatestJson = serde_json::from_slice(&raw).map_err(|err| {
        tracing::warn!(path = %path.display(), %err, "invalid latest.json");
        not_published()
    })?;
    if !safe_file_name(&latest.file) {
        tracing::warn!(path = %path.display(), "latest.json names an unsafe file");
        return Err(not_published());
    }
    Ok(Json(AndroidRelease {
        url: format!("/downloads/android/{}", latest.file),
        version_name: latest.version_name,
        version_code: latest.version_code,
        sha256: latest.sha256,
        size_bytes: latest.size_bytes,
        published_at: latest.published_at,
    }))
}

/// Serves one file from the android dist dir with Range support; never lists.
pub async fn android_download(State(state): State<AppState>, Path(file): Path<String>, request: Request) -> Response {
    if !safe_file_name(&file) {
        return ApiError::not_found("file").into_response();
    }
    let path = android_dir(&state).join(&file);
    if !tokio::fs::metadata(&path).await.is_ok_and(|m| m.is_file()) {
        return ApiError::not_found("file").into_response();
    }
    let serve = if file.to_ascii_lowercase().ends_with(".apk") {
        ServeFile::new_with_mime(&path, &APK_MIME.parse().expect("valid mime"))
    } else {
        ServeFile::new(&path)
    };
    match serve.oneshot(request).await {
        Ok(response) => response.into_response(),
        Err(_) => ApiError::internal().into_response(),
    }
}
