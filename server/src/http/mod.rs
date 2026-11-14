//! HTTP adapter: axum routes for `/api/v1` plus the web client SPA.

mod auth;
mod error;
mod extract;
mod favorites;
mod library;
mod lyrics;
mod playlists;
mod stats;
mod streaming;

use axum::Json;
use axum::extract::{Request, State};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post, put};
use axum::Router;
use serde::Serialize;
use serde_json::{Value, json};
use tower::ServiceExt;
use tower_http::cors::CorsLayer;
use tower_http::services::{ServeDir, ServeFile};
use tower_http::trace::TraceLayer;

pub use error::ApiError;

use crate::app::AppState;

/// Contract list envelope.
fn list<T: Serialize>(items: Vec<T>, total: i64) -> Json<Value> {
    Json(json!({ "items": items, "total": total }))
}

async fn health() -> Json<Value> {
    Json(json!({ "status": "ok", "version": env!("CARGO_PKG_VERSION") }))
}

async fn not_found() -> ApiError {
    ApiError::not_found("route")
}

/// Non-API paths are served from the web build with SPA fallback to `index.html`.
async fn web_fallback(State(state): State<AppState>, request: Request) -> Response {
    let path = request.uri().path();
    let web_dir = &state.config.web_dir;
    if path == "/api" || path.starts_with("/api/") || !web_dir.is_dir() {
        return not_found().await.into_response();
    }
    let index = ServeFile::new(web_dir.join("index.html"));
    match ServeDir::new(web_dir).fallback(index).oneshot(request).await {
        Ok(response) => response.into_response(),
        Err(_) => ApiError::internal().into_response(),
    }
}

pub fn router(state: AppState) -> Router {
    let api = Router::new()
        .route("/health", get(health))
        .route("/auth/login", post(auth::login))
        .route("/me", get(auth::me))
        .route("/tracks", get(library::list_tracks))
        .route("/tracks/{id}", get(library::get_track))
        .route("/tracks/{id}/stream", get(streaming::stream))
        .route("/tracks/{id}/cover", get(library::cover))
        .route("/tracks/{id}/waveform", get(streaming::waveform))
        .route("/tracks/{id}/lyrics", get(lyrics::get_lyrics))
        .route("/albums", get(library::list_albums))
        .route("/albums/{id}", get(library::get_album))
        .route("/artists", get(library::list_artists))
        .route("/playlists", get(playlists::list_playlists).post(playlists::create_playlist))
        .route(
            "/playlists/{id}",
            get(playlists::get_playlist).patch(playlists::update_playlist).delete(playlists::delete_playlist),
        )
        .route("/favorites", get(favorites::list_favorites))
        .route("/favorites/{track_id}", put(favorites::add_favorite).delete(favorites::remove_favorite))
        .route("/plays", post(stats::record_plays))
        .route("/stats/summary", get(stats::summary))
        .route("/library/changes", get(library::changes))
        .route("/library/scan", post(library::scan))
        .fallback(not_found);

    // Spans record only method and path: query strings may carry `?token=`.
    let trace = TraceLayer::new_for_http().make_span_with(|request: &Request| {
        tracing::info_span!("http", method = %request.method(), path = %request.uri().path())
    });

    Router::new()
        .nest("/api/v1", api)
        .fallback(web_fallback)
        .layer(CorsLayer::permissive())
        .layer(trace)
        .with_state(state)
}
