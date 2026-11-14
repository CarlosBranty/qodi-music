use axum::Json;
use axum::extract::{Path, State};

use super::error::{ApiError, ApiResult};
use super::extract::AuthUser;
use crate::app::AppState;
use crate::library::{LibraryCatalog, sidecar_lyrics_path};
use crate::lyrics::{Lyrics, parse};

/// Sidecar `<stem>.lrc` first, then the embedded lyrics tag.
pub async fn get_lyrics(State(state): State<AppState>, _user: AuthUser, Path(id): Path<String>) -> ApiResult<Json<Lyrics>> {
    let file = state.store.track_file(&id).await?.ok_or_else(|| ApiError::not_found("track"))?;
    let path = state.config.music_dir.join(&file.path);
    let tags = state.tags.clone();
    let lyrics = tokio::task::spawn_blocking(move || {
        let sidecar = std::fs::read(sidecar_lyrics_path(&path)).ok().map(|b| String::from_utf8_lossy(&b).into_owned());
        sidecar.as_deref().and_then(parse).or_else(|| tags.embedded_lyrics(&path).as_deref().and_then(parse))
    })
    .await
    .map_err(|_| ApiError::internal())?;
    lyrics.map(Json).ok_or_else(|| ApiError::not_found("lyrics"))
}
