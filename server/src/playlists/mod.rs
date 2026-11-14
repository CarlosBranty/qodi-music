//! Playlists: user-owned ordered lists of tracks.

use std::future::Future;

use serde::Serialize;

use crate::library::Track;

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct Playlist {
    pub id: String,
    pub name: String,
    pub track_count: i64,
    pub duration_ms: i64,
    pub cover_track_id: Option<String>,
    #[serde(serialize_with = "crate::time::serialize_ms")]
    pub created_at: i64,
    #[serde(serialize_with = "crate::time::serialize_ms")]
    pub updated_at: i64,
}

#[derive(Debug, Clone, Default)]
pub struct PlaylistChanges {
    pub name: Option<String>,
    /// Replaces the whole ordered list.
    pub track_ids: Option<Vec<String>>,
}

#[derive(Debug)]
pub enum UpdateOutcome {
    Updated(Playlist),
    NotFound,
    UnknownTrack(String),
}

/// Trims a playlist name; empty names are rejected.
pub fn validate_name(name: &str) -> Option<String> {
    let name = name.trim();
    (!name.is_empty()).then(|| name.to_string())
}

/// Port: playlist persistence, always scoped to the owning user.
pub trait PlaylistRepository: Send + Sync {
    fn playlists(&self, user_id: &str) -> impl Future<Output = anyhow::Result<Vec<Playlist>>> + Send;
    fn playlist(&self, user_id: &str, id: &str) -> impl Future<Output = anyhow::Result<Option<Playlist>>> + Send;
    fn playlist_tracks(&self, user_id: &str, id: &str) -> impl Future<Output = anyhow::Result<Vec<Track>>> + Send;
    fn create_playlist(&self, user_id: &str, name: &str, now_ms: i64)
    -> impl Future<Output = anyhow::Result<Playlist>> + Send;
    fn update_playlist(
        &self,
        user_id: &str,
        id: &str,
        changes: PlaylistChanges,
        now_ms: i64,
    ) -> impl Future<Output = anyhow::Result<UpdateOutcome>> + Send;
    fn delete_playlist(&self, user_id: &str, id: &str) -> impl Future<Output = anyhow::Result<bool>> + Send;
}
