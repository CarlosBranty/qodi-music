use anyhow::Result;

use super::SqliteStore;
use crate::favorites::FavoritesRepository;
use crate::library::Track;

impl FavoritesRepository for SqliteStore {
    async fn favorites(&self, user_id: &str) -> Result<Vec<Track>> {
        Ok(sqlx::query_as::<_, Track>(concat!(
            "SELECT ",
            track_columns!(),
            " FROM favorites fav JOIN tracks t ON t.id = fav.track_id WHERE fav.user_id = ?1 \
             ORDER BY fav.created_at DESC, fav.rowid DESC"
        ))
        .bind(user_id)
        .fetch_all(&self.pool)
        .await?)
    }

    async fn add_favorite(&self, user_id: &str, track_id: &str, now_ms: i64) -> Result<bool> {
        let exists: Option<i64> = sqlx::query_scalar("SELECT 1 FROM tracks WHERE id = ?1")
            .bind(track_id)
            .fetch_optional(&self.pool)
            .await?;
        if exists.is_none() {
            return Ok(false);
        }
        sqlx::query("INSERT OR IGNORE INTO favorites (user_id, track_id, created_at) VALUES (?1, ?2, ?3)")
            .bind(user_id)
            .bind(track_id)
            .bind(now_ms)
            .execute(&self.pool)
            .await?;
        Ok(true)
    }

    async fn remove_favorite(&self, user_id: &str, track_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM favorites WHERE user_id = ?1 AND track_id = ?2")
            .bind(user_id)
            .bind(track_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }
}
