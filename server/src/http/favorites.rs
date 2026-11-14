use axum::Json;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use serde_json::Value;

use super::error::{ApiError, ApiResult};
use super::extract::AuthUser;
use super::list;
use crate::app::AppState;
use crate::favorites::FavoritesRepository;
use crate::time::now_ms;

pub async fn list_favorites(State(state): State<AppState>, AuthUser(user): AuthUser) -> ApiResult<Json<Value>> {
    let items = state.store.favorites(&user.id).await?;
    let total = items.len() as i64;
    Ok(list(items, total))
}

pub async fn add_favorite(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    Path(track_id): Path<String>,
) -> ApiResult<StatusCode> {
    if state.store.add_favorite(&user.id, &track_id, now_ms()).await? {
        Ok(StatusCode::NO_CONTENT)
    } else {
        Err(ApiError::not_found("track"))
    }
}

pub async fn remove_favorite(
    State(state): State<AppState>,
    AuthUser(user): AuthUser,
    Path(track_id): Path<String>,
) -> ApiResult<StatusCode> {
    state.store.remove_favorite(&user.id, &track_id).await?;
    Ok(StatusCode::NO_CONTENT)
}
