use anyhow::Result;

use super::SqliteStore;
use crate::library::LibraryCatalog;
use crate::stats::{DailyListen, PlayRecord, StatsRange, StatsRepository, Summary, TOP_LIMIT, TopArtist, TopTrack};

impl StatsRepository for SqliteStore {
    async fn record_plays(&self, user_id: &str, plays: &[PlayRecord]) -> Result<u64> {
        let mut tx = self.pool.begin().await?;
        let mut accepted = 0;
        for play in plays {
            accepted += sqlx::query(
                "INSERT OR IGNORE INTO plays (client_id, user_id, track_id, played_at, listened_ms) \
                 VALUES (?1, ?2, ?3, ?4, ?5)",
            )
            .bind(&play.client_id)
            .bind(user_id)
            .bind(&play.track_id)
            .bind(play.played_at_ms)
            .bind(play.listened_ms)
            .execute(&mut *tx)
            .await?
            .rows_affected();
        }
        tx.commit().await?;
        Ok(accepted)
    }

    async fn summary(&self, user_id: &str, range: StatsRange, now_ms: i64) -> Result<Summary> {
        let since = range.since_ms(now_ms);
        let (total_plays, total_listen_ms, unique_tracks): (i64, i64, i64) = sqlx::query_as(
            "SELECT COUNT(*), COALESCE(SUM(listened_ms), 0), COUNT(DISTINCT track_id) FROM plays \
             WHERE user_id = ?1 AND (?2 IS NULL OR played_at >= ?2)",
        )
        .bind(user_id)
        .bind(since)
        .fetch_one(&self.pool)
        .await?;

        let top: Vec<(String, i64)> = sqlx::query_as(
            "SELECT p.track_id, COUNT(*) AS plays FROM plays p JOIN tracks t ON t.id = p.track_id \
             WHERE p.user_id = ?1 AND (?2 IS NULL OR p.played_at >= ?2) \
             GROUP BY p.track_id ORDER BY plays DESC, MAX(p.played_at) DESC LIMIT ?3",
        )
        .bind(user_id)
        .bind(since)
        .bind(TOP_LIMIT)
        .fetch_all(&self.pool)
        .await?;
        let mut top_tracks = Vec::with_capacity(top.len());
        for (track_id, plays) in top {
            if let Some(track) = self.track(user_id, &track_id).await? {
                top_tracks.push(TopTrack { track, plays });
            }
        }

        let top_artists = sqlx::query_as::<_, TopArtist>(
            "SELECT t.artist_id AS artist_id, MIN(t.artist) AS name, COUNT(*) AS plays \
             FROM plays p JOIN tracks t ON t.id = p.track_id \
             WHERE p.user_id = ?1 AND (?2 IS NULL OR p.played_at >= ?2) \
             GROUP BY t.artist_id ORDER BY plays DESC, MAX(p.played_at) DESC LIMIT ?3",
        )
        .bind(user_id)
        .bind(since)
        .bind(TOP_LIMIT)
        .fetch_all(&self.pool)
        .await?;

        let daily = sqlx::query_as::<_, DailyListen>(
            "SELECT strftime('%Y-%m-%d', played_at / 1000, 'unixepoch') AS date, \
             SUM(listened_ms) AS listen_ms FROM plays \
             WHERE user_id = ?1 AND (?2 IS NULL OR played_at >= ?2) GROUP BY date ORDER BY date",
        )
        .bind(user_id)
        .bind(since)
        .fetch_all(&self.pool)
        .await?;

        Ok(Summary {
            range: range.as_str(),
            total_plays,
            total_listen_ms,
            unique_tracks,
            top_tracks,
            top_artists,
            daily,
        })
    }
}
