use axum::Json;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use serde::Deserialize;
use serde_json::{Value, json};

use super::error::{ApiError, ApiResult};
use super::extract::{ApiJson, AuthUser};
use super::list;
use crate::app::AppState;
use crate::playlists::{Playlist, PlaylistChanges, PlaylistRepository, UpdateOutcome, validate_name};
use crate::time::now_ms;

pub async fn list_playlists(State(state): State<AppState>, AuthUser(user): AuthUser) -> ApiResult<Json<Value>> {
    let items = state.store.playlists(&user.id).await?;
    let total = items.len() as i64;
    Ok(list(items, total))
}

#[derive(Deserialize)]
pub struct CreateBody {
    name: String,
}

pub async fn create_playlist(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    ApiJson(body): ApiJson<CreateBody>,
) -> ApiResult<(StatusCode, Json<Playlist>)> {
    let name = validate_name(&body.name).ok_or_else(|| ApiError::bad_request("name must not be empty"))?;
    let playlist = state.store.create_playlist(&user.id, &name, now_ms()).await?;
    Ok((StatusCode::CREATED, Json(playlist)))
}

pub async fn get_playlist(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    Path(id): Path<String>,
) -> ApiResult<Json<Value>> {
    let playlist = state.store.playlist(&user.id, &id).await?.ok_or_else(|| ApiError::not_found("playlist"))?;
    let tracks = state.store.playlist_tracks(&user.id, &id).await?;
    Ok(Json(json!({ "playlist": playlist, "tracks": tracks })))
}

#[derive(Deserialize)]
pub struct UpdateBody {
    name: Option<String>,
    track_ids: Option<Vec<String>>,
}

pub async fn update_playlist(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    Path(id): Path<String>,
    ApiJson(body): ApiJson<UpdateBody>,
) -> ApiResult<Json<Playlist>> {
    let name = match body.name {
        Some(name) => Some(validate_name(&name).ok_or_else(|| ApiError::bad_request("name must not be empty"))?),
        None => None,
    };
    let changes = PlaylistChanges { name, track_ids: body.track_ids };
    match state.store.update_playlist(&user.id, &id, changes, now_ms()).await? {
        UpdateOutcome::Updated(playlist) => Ok(Json(playlist)),
        UpdateOutcome::NotFound => Err(ApiError::not_found("playlist")),
        UpdateOutcome::UnknownTrack(track) => Err(ApiError::bad_request(format!("unknown track id {track}"))),
    }
}

pub async fn delete_playlist(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    Path(id): Path<String>,
) -> ApiResult<StatusCode> {
    if state.store.delete_playlist(&user.id, &id).await? {
        Ok(StatusCode::NO_CONTENT)
    } else {
        Err(ApiError::not_found("playlist"))
    }
}
