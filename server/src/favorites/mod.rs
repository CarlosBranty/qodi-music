//! Favorites: per-user liked tracks, most recently favorited first.

use std::future::Future;

use crate::library::Track;

/// Port: favorites persistence. Adding and removing are idempotent.
pub trait FavoritesRepository: Send + Sync {
    fn favorites(&self, user_id: &str) -> impl Future<Output = anyhow::Result<Vec<Track>>> + Send;
    /// Returns `false` when the track does not exist.
    fn add_favorite(&self, user_id: &str, track_id: &str, now_ms: i64)
    -> impl Future<Output = anyhow::Result<bool>> + Send;
    fn remove_favorite(&self, user_id: &str, track_id: &str) -> impl Future<Output = anyhow::Result<()>> + Send;
}
