use std::path::PathBuf;

use axum::Json;
use axum::body::Body;
use axum::extract::{Path, State};
use axum::http::header::{ACCEPT_RANGES, IF_MODIFIED_SINCE, IF_RANGE, IF_UNMODIFIED_SINCE, RANGE};
use axum::http::{HeaderMap, HeaderValue, Method, Request, StatusCode};
use axum::response::Response;
use serde::Deserialize;
use serde_json::{Value, json};
use tower::ServiceExt;
use tower_http::services::ServeFile;

use super::error::{ApiError, ApiResult};
use super::extract::{ApiQuery, AuthUser};
use crate::app::AppState;
use crate::library::LibraryCatalog;
use crate::streaming::{StreamFormat, Target, WAVEFORM_PEAKS, WaveformCache, content_type, normalize_peaks, parse_bitrate};

#[derive(Deserialize)]
pub struct StreamQuery {
    format: Option<String>,
    bitrate: Option<String>,
}

pub async fn stream(
    State(state): State<AppState>,
    _user: AuthUser,
    Path(id): Path<String>,
    ApiQuery(query): ApiQuery<StreamQuery>,
    headers: HeaderMap,
) -> ApiResult<Response> {
    let format = StreamFormat::parse(query.format.as_deref())
        .ok_or_else(|| ApiError::bad_request("format must be original, opus or flac"))?;
    let bitrate = parse_bitrate(query.bitrate.as_deref())
        .ok_or_else(|| ApiError::bad_request("bitrate must be 64, 96, 128 or 192"))?;
    let file = state.store.track_file(&id).await?.ok_or_else(|| ApiError::not_found("track"))?;
    let source = state.config.music_dir.join(&file.path);
    if !source.is_file() {
        return Err(ApiError::not_found("track file"));
    }
    let target = match format {
        StreamFormat::Original => return serve_file(source, content_type(&file.format), &headers).await,
        StreamFormat::Opus => Target::Opus { bitrate_kbps: bitrate },
        StreamFormat::Flac => Target::Flac,
    };
    let cached = state.transcodes.get(&file.id, &source, target).await?;
    serve_file(cached, target.content_type(), &headers).await
}

/// Serves a file with `Range`/conditional request support via `ServeFile`.
async fn serve_file(path: PathBuf, mime: &str, headers: &HeaderMap) -> ApiResult<Response> {
    let mut request = Request::builder().method(Method::GET).uri("/").body(Body::empty()).map_err(|_| ApiError::internal())?;
    for name in [RANGE, IF_RANGE, IF_MODIFIED_SINCE, IF_UNMODIFIED_SINCE] {
        if let Some(value) = headers.get(&name) {
            request.headers_mut().insert(name, value.clone());
        }
    }
    let mime = mime.parse().unwrap_or(mime::APPLICATION_OCTET_STREAM);
    let response = ServeFile::new_with_mime(&path, &mime).oneshot(request).await.map_err(|_| ApiError::internal())?;
    if response.status() == StatusCode::NOT_FOUND {
        return Err(ApiError::not_found("track file"));
    }
    let mut response = response.map(Body::new);
    response.headers_mut().entry(ACCEPT_RANGES).or_insert(HeaderValue::from_static("bytes"));
    Ok(response)
}

pub async fn waveform(State(state): State<AppState>, _user: AuthUser, Path(id): Path<String>) -> ApiResult<Json<Value>> {
    if let Some(peaks) = state.store.cached_waveform(&id).await?.filter(|p| p.len() == WAVEFORM_PEAKS) {
        return Ok(Json(json!({ "peaks": peaks })));
    }
    let file = state.store.track_file(&id).await?.ok_or_else(|| ApiError::not_found("track"))?;
    let path = state.config.music_dir.join(&file.path);
    let analyzer = state.waveform.clone();
    let raw = tokio::task::spawn_blocking(move || analyzer.raw_peaks(&path))
        .await
        .map_err(|_| ApiError::internal())??;
    let peaks = normalize_peaks(&raw, WAVEFORM_PEAKS);
    state.store.store_waveform(&id, &peaks).await?;
    Ok(Json(json!({ "peaks": peaks })))
}
