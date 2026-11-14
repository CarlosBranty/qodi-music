use axum::Json;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::http::header::{CACHE_CONTROL, CONTENT_TYPE};
use axum::response::{IntoResponse, Response};
use serde::Deserialize;
use serde_json::{Value, json};

use super::error::{ApiError, ApiResult};
use super::extract::{ApiQuery, AuthUser, non_empty};
use super::list;
use crate::app::AppState;
use crate::library::{
    Album, Artist, Cover, LibraryCatalog, Page, Track, TrackFilter, find_sidecar_cover, mime_for_image_path,
};
use crate::time::{format_ms, now_ms, parse_rfc3339};

#[derive(Deserialize)]
pub struct TracksQuery {
    q: Option<String>,
    artist_id: Option<String>,
    album_id: Option<String>,
    limit: Option<u32>,
    offset: Option<u32>,
}

pub async fn list_tracks(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    ApiQuery(query): ApiQuery<TracksQuery>,
) -> ApiResult<Json<Value>> {
    let filter = TrackFilter {
        query: non_empty(query.q),
        artist_id: non_empty(query.artist_id),
        album_id: non_empty(query.album_id),
    };
    let (items, total) = state.store.tracks(&user.id, &filter, Page::new(query.limit, query.offset)).await?;
    Ok(list(items, total))
}

pub async fn get_track(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    Path(id): Path<String>,
) -> ApiResult<Json<Track>> {
    state.store.track(&user.id, &id).await?.map(Json).ok_or_else(|| ApiError::not_found("track"))
}

pub async fn cover(State(state): State<AppState>, _user: AuthUser, Path(id): Path<String>) -> ApiResult<Response> {
    let file = state.store.track_file(&id).await?.ok_or_else(|| ApiError::not_found("track"))?;
    let path = state.config.music_dir.join(&file.path);
    let tags = state.tags.clone();
    let cover = tokio::task::spawn_blocking(move || {
        tags.embedded_cover(&path).or_else(|| {
            let sidecar = find_sidecar_cover(path.parent()?)?;
            let data = std::fs::read(&sidecar).ok()?;
            Some(Cover { data, mime: mime_for_image_path(&sidecar).to_string() })
        })
    })
    .await
    .map_err(|_| ApiError::internal())?
    .ok_or_else(|| ApiError::not_found("cover"))?;
    Ok((
        StatusCode::OK,
        [(CONTENT_TYPE, cover.mime), (CACHE_CONTROL, "private, max-age=86400".to_string())],
        cover.data,
    )
        .into_response())
}

#[derive(Deserialize)]
pub struct AlbumsQuery {
    artist_id: Option<String>,
    limit: Option<u32>,
    offset: Option<u32>,
}

pub async fn list_albums(
    State(state): State<AppState>,
    _user: AuthUser,
    ApiQuery(query): ApiQuery<AlbumsQuery>,
) -> ApiResult<Json<Value>> {
    let artist_id = non_empty(query.artist_id);
    let (items, total): (Vec<Album>, i64) =
        state.store.albums(artist_id.as_deref(), Page::new(query.limit, query.offset)).await?;
    Ok(list(items, total))
}

pub async fn get_album(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    Path(id): Path<String>,
) -> ApiResult<Json<Value>> {
    let album = state.store.album(&id).await?.ok_or_else(|| ApiError::not_found("album"))?;
    let filter = TrackFilter { album_id: Some(id), ..Default::default() };
    let (tracks, _) = state.store.tracks(&user.id, &filter, Page::ALL).await?;
    Ok(Json(json!({ "album": album, "tracks": tracks })))
}

#[derive(Deserialize)]
pub struct PageQuery {
    limit: Option<u32>,
    offset: Option<u32>,
}

pub async fn list_artists(
    State(state): State<AppState>,
    _user: AuthUser,
    ApiQuery(query): ApiQuery<PageQuery>,
) -> ApiResult<Json<Value>> {
    let (items, total): (Vec<Artist>, i64) = state.store.artists(Page::new(query.limit, query.offset)).await?;
    Ok(list(items, total))
}

#[derive(Deserialize)]
pub struct ChangesQuery {
    since: Option<String>,
}

pub async fn changes(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    ApiQuery(query): ApiQuery<ChangesQuery>,
) -> ApiResult<Json<Value>> {
    let since = match non_empty(query.since) {
        None => None,
        Some(raw) => Some(parse_rfc3339(&raw).ok_or_else(|| ApiError::bad_request("since must be RFC 3339"))?),
    };
    // Taken before reading so nothing committed meanwhile is skipped by the next delta.
    let server_time = now_ms();
    let (tracks, removed) = state.store.changes(&user.id, since).await?;
    Ok(Json(json!({
        "server_time": format_ms(server_time),
        "tracks": tracks,
        "removed_track_ids": removed,
    })))
}

pub async fn scan(State(state): State<AppState>, _user: AuthUser) -> (StatusCode, Json<Value>) {
    state.scanner.request();
    (StatusCode::ACCEPTED, Json(json!({ "status": "scanning" })))
}
