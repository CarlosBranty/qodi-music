use anyhow::Result;

use super::SqliteStore;
use crate::library::Track;
use crate::playlists::{Playlist, PlaylistChanges, PlaylistRepository, UpdateOutcome};

/// Playlist columns; `?1` = user id, `?2` = playlist id (or NULL for all).
const PLAYLIST_SELECT: &str = "SELECT p.id, p.name, p.created_at, p.updated_at, \
     (SELECT COUNT(*) FROM playlist_tracks pt JOIN tracks t ON t.id = pt.track_id \
      WHERE pt.playlist_id = p.id) AS track_count, \
     (SELECT COALESCE(SUM(t.duration_ms), 0) FROM playlist_tracks pt JOIN tracks t ON t.id = pt.track_id \
      WHERE pt.playlist_id = p.id) AS duration_ms, \
     (SELECT t.id FROM playlist_tracks pt JOIN tracks t ON t.id = pt.track_id \
      WHERE pt.playlist_id = p.id AND t.has_cover = 1 ORDER BY pt.position LIMIT 1) AS cover_track_id \
     FROM playlists p WHERE p.user_id = ?1 AND (?2 IS NULL OR p.id = ?2) \
     ORDER BY p.updated_at DESC, p.rowid DESC";

impl PlaylistRepository for SqliteStore {
    async fn playlists(&self, user_id: &str) -> Result<Vec<Playlist>> {
        Ok(sqlx::query_as::<_, Playlist>(PLAYLIST_SELECT)
            .bind(user_id)
            .bind(None::<String>)
            .fetch_all(&self.pool)
            .await?)
    }

    async fn playlist(&self, user_id: &str, id: &str) -> Result<Option<Playlist>> {
        Ok(sqlx::query_as::<_, Playlist>(PLAYLIST_SELECT)
            .bind(user_id)
            .bind(id)
            .fetch_optional(&self.pool)
            .await?)
    }

    async fn playlist_tracks(&self, user_id: &str, id: &str) -> Result<Vec<Track>> {
        Ok(sqlx::query_as::<_, Track>(concat!(
            "SELECT ",
            track_columns!(),
            " FROM playlist_tracks pt JOIN playlists p ON p.id = pt.playlist_id \
             JOIN tracks t ON t.id = pt.track_id \
             WHERE p.user_id = ?1 AND pt.playlist_id = ?2 ORDER BY pt.position"
        ))
        .bind(user_id)
        .bind(id)
        .fetch_all(&self.pool)
        .await?)
    }

    async fn create_playlist(&self, user_id: &str, name: &str, now_ms: i64) -> Result<Playlist> {
        let id = uuid::Uuid::new_v4().simple().to_string();
        sqlx::query("INSERT INTO playlists (id, user_id, name, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?4)")
            .bind(&id)
            .bind(user_id)
            .bind(name)
            .bind(now_ms)
            .execute(&self.pool)
            .await?;
        self.playlist(user_id, &id).await?.ok_or_else(|| anyhow::anyhow!("playlist vanished after insert"))
    }

    async fn update_playlist(
        &self,
        user_id: &str,
        id: &str,
        changes: PlaylistChanges,
        now_ms: i64,
    ) -> Result<UpdateOutcome> {
        let mut tx = self.pool.begin().await?;
        let owned: Option<String> = sqlx::query_scalar("SELECT id FROM playlists WHERE id = ?1 AND user_id = ?2")
            .bind(id)
            .bind(user_id)
            .fetch_optional(&mut *tx)
            .await?;
        if owned.is_none() {
            return Ok(UpdateOutcome::NotFound);
        }
        if let Some(name) = &changes.name {
            sqlx::query("UPDATE playlists SET name = ?2 WHERE id = ?1").bind(id).bind(name).execute(&mut *tx).await?;
        }
        if let Some(track_ids) = &changes.track_ids {
            for track_id in track_ids {
                let exists: Option<i64> = sqlx::query_scalar("SELECT 1 FROM tracks WHERE id = ?1")
                    .bind(track_id)
                    .fetch_optional(&mut *tx)
                    .await?;
                if exists.is_none() {
                    return Ok(UpdateOutcome::UnknownTrack(track_id.clone()));
                }
            }
            sqlx::query("DELETE FROM playlist_tracks WHERE playlist_id = ?1").bind(id).execute(&mut *tx).await?;
            for (position, track_id) in track_ids.iter().enumerate() {
                sqlx::query("INSERT INTO playlist_tracks (playlist_id, position, track_id) VALUES (?1, ?2, ?3)")
                    .bind(id)
                    .bind(position as i64)
                    .bind(track_id)
                    .execute(&mut *tx)
                    .await?;
            }
        }
        sqlx::query("UPDATE playlists SET updated_at = ?2 WHERE id = ?1").bind(id).bind(now_ms).execute(&mut *tx).await?;
        tx.commit().await?;
        Ok(match self.playlist(user_id, id).await? {
            Some(playlist) => UpdateOutcome::Updated(playlist),
            None => UpdateOutcome::NotFound,
        })
    }

    async fn delete_playlist(&self, user_id: &str, id: &str) -> Result<bool> {
        let mut tx = self.pool.begin().await?;
        let deleted = sqlx::query("DELETE FROM playlists WHERE id = ?1 AND user_id = ?2")
            .bind(id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?
            .rows_affected();
        if deleted > 0 {
            sqlx::query("DELETE FROM playlist_tracks WHERE playlist_id = ?1").bind(id).execute(&mut *tx).await?;
        }
        tx.commit().await?;
        Ok(deleted > 0)
    }
}
