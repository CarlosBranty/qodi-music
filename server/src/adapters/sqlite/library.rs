use std::collections::HashMap;

use anyhow::Result;

use super::SqliteStore;
use crate::library::scanner::{IndexedFile, LibraryIndex, ScanChanges};
use crate::library::{Album, Artist, LibraryCatalog, Page, Track, TrackFile, TrackFilter};
use crate::streaming::WaveformCache;

const TRACK_FILTER: &str = "(?2 IS NULL OR t.search_text LIKE ?2 ESCAPE '\\') \
     AND (?3 IS NULL OR t.artist_id = ?3) AND (?4 IS NULL OR t.album_id = ?4)";

fn like_pattern(query: &str) -> String {
    let escaped = query.to_lowercase().replace('\\', "\\\\").replace('%', "\\%").replace('_', "\\_");
    format!("%{escaped}%")
}

const ALBUM_COLUMNS: &str = "SELECT t.album_id AS id, MIN(t.album) AS title, MIN(t.album_artist) AS artist, \
     MIN(t.album_artist_id) AS artist_id, MAX(t.year) AS year, COUNT(*) AS track_count, \
     SUM(t.duration_ms) AS duration_ms, \
     (SELECT c.id FROM tracks c WHERE c.album_id = t.album_id AND c.has_cover = 1 \
      ORDER BY c.disc_number, c.track_number, c.title LIMIT 1) AS cover_track_id \
     FROM tracks t";

impl LibraryCatalog for SqliteStore {
    async fn tracks(&self, user_id: &str, filter: &TrackFilter, page: Page) -> Result<(Vec<Track>, i64)> {
        let pattern = filter.query.as_deref().map(like_pattern);
        let items = sqlx::query_as::<_, Track>(sqlx::AssertSqlSafe(format!(
            "SELECT {} FROM tracks t WHERE {TRACK_FILTER}{} LIMIT ?5 OFFSET ?6",
            track_columns!(),
            track_order!()
        )))
        .bind(user_id)
        .bind(&pattern)
        .bind(&filter.artist_id)
        .bind(&filter.album_id)
        .bind(page.limit)
        .bind(page.offset)
        .fetch_all(&self.pool)
        .await?;
        let total: i64 =
            sqlx::query_scalar(sqlx::AssertSqlSafe(format!("SELECT COUNT(*) FROM tracks t WHERE ?1 IS ?1 AND {TRACK_FILTER}")))
                .bind(user_id)
                .bind(&pattern)
                .bind(&filter.artist_id)
                .bind(&filter.album_id)
                .fetch_one(&self.pool)
                .await?;
        Ok((items, total))
    }

    async fn track(&self, user_id: &str, id: &str) -> Result<Option<Track>> {
        Ok(sqlx::query_as::<_, Track>(concat!("SELECT ", track_columns!(), " FROM tracks t WHERE t.id = ?2"))
            .bind(user_id)
            .bind(id)
            .fetch_optional(&self.pool)
            .await?)
    }

    async fn track_file(&self, id: &str) -> Result<Option<TrackFile>> {
        Ok(sqlx::query_as::<_, TrackFile>("SELECT id, path, format FROM tracks WHERE id = ?1")
            .bind(id)
            .fetch_optional(&self.pool)
            .await?)
    }

    async fn albums(&self, artist_id: Option<&str>, page: Page) -> Result<(Vec<Album>, i64)> {
        const FILTER: &str = "(?1 IS NULL OR t.album_id IN \
             (SELECT album_id FROM tracks WHERE artist_id = ?1 OR album_artist_id = ?1))";
        let items = sqlx::query_as::<_, Album>(sqlx::AssertSqlSafe(format!(
            "{ALBUM_COLUMNS} WHERE {FILTER} GROUP BY t.album_id \
             ORDER BY MIN(t.album_artist) COLLATE NOCASE, MAX(t.year), MIN(t.album) COLLATE NOCASE, t.album_id \
             LIMIT ?2 OFFSET ?3"
        )))
        .bind(artist_id)
        .bind(page.limit)
        .bind(page.offset)
        .fetch_all(&self.pool)
        .await?;
        let total: i64 =
            sqlx::query_scalar(sqlx::AssertSqlSafe(format!("SELECT COUNT(DISTINCT t.album_id) FROM tracks t WHERE {FILTER}")))
                .bind(artist_id)
                .fetch_one(&self.pool)
                .await?;
        Ok((items, total))
    }

    async fn album(&self, id: &str) -> Result<Option<Album>> {
        Ok(sqlx::query_as::<_, Album>(sqlx::AssertSqlSafe(format!(
            "{ALBUM_COLUMNS} WHERE t.album_id = ?1 GROUP BY t.album_id"
        )))
        .bind(id)
        .fetch_optional(&self.pool)
        .await?)
    }

    async fn artists(&self, page: Page) -> Result<(Vec<Artist>, i64)> {
        let items = sqlx::query_as::<_, Artist>(
            "SELECT artist_id AS id, MIN(artist) AS name, COUNT(DISTINCT album_id) AS album_count, \
             COUNT(*) AS track_count FROM tracks GROUP BY artist_id \
             ORDER BY MIN(artist) COLLATE NOCASE, artist_id LIMIT ?1 OFFSET ?2",
        )
        .bind(page.limit)
        .bind(page.offset)
        .fetch_all(&self.pool)
        .await?;
        let total: i64 = sqlx::query_scalar("SELECT COUNT(DISTINCT artist_id) FROM tracks")
            .fetch_one(&self.pool)
            .await?;
        Ok((items, total))
    }

    async fn changes(&self, user_id: &str, since_ms: Option<i64>) -> Result<(Vec<Track>, Vec<String>)> {
        let tracks = sqlx::query_as::<_, Track>(concat!(
            "SELECT ",
            track_columns!(),
            " FROM tracks t WHERE ?2 IS NULL OR t.updated_at > ?2",
            track_order!()
        ))
        .bind(user_id)
        .bind(since_ms)
        .fetch_all(&self.pool)
        .await?;
        // A full snapshot replaces the client's library, so it carries no removals.
        let removed = match since_ms {
            None => Vec::new(),
            Some(since) => {
                sqlx::query_scalar("SELECT track_id FROM tombstones WHERE removed_at > ?1 ORDER BY removed_at, track_id")
                    .bind(since)
                    .fetch_all(&self.pool)
                    .await?
            }
        };
        Ok((tracks, removed))
    }
}

#[derive(sqlx::FromRow)]
struct IndexedRow {
    id: String,
    path: String,
    size_bytes: i64,
    mtime_ms: i64,
    has_embedded_cover: bool,
    has_embedded_lyrics: bool,
    has_cover: bool,
    has_lyrics: bool,
}

impl LibraryIndex for SqliteStore {
    async fn snapshot(&self) -> Result<HashMap<String, IndexedFile>> {
        let rows = sqlx::query_as::<_, IndexedRow>(
            "SELECT id, path, size_bytes, mtime_ms, has_embedded_cover, has_embedded_lyrics, has_cover, has_lyrics \
             FROM tracks",
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| {
                let file = IndexedFile {
                    id: r.id,
                    size_bytes: r.size_bytes,
                    mtime_ms: r.mtime_ms,
                    has_embedded_cover: r.has_embedded_cover,
                    has_embedded_lyrics: r.has_embedded_lyrics,
                    has_cover: r.has_cover,
                    has_lyrics: r.has_lyrics,
                };
                (r.path, file)
            })
            .collect())
    }

    async fn apply(&self, changes: &ScanChanges, now_ms: i64) -> Result<()> {
        let mut tx = self.pool.begin().await?;
        for record in &changes.upserts {
            let t = &record.track;
            sqlx::query(
                "INSERT INTO tracks (id, path, title, artist, artist_id, album, album_id, album_artist, \
                 album_artist_id, track_number, disc_number, year, genre, duration_ms, format, bitrate_kbps, \
                 size_bytes, mtime_ms, has_embedded_cover, has_embedded_lyrics, has_cover, has_lyrics, \
                 search_text, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, \
                 ?20, ?21, ?22, ?23, ?24) \
                 ON CONFLICT (id) DO UPDATE SET path = excluded.path, title = excluded.title, \
                 artist = excluded.artist, artist_id = excluded.artist_id, album = excluded.album, \
                 album_id = excluded.album_id, album_artist = excluded.album_artist, \
                 album_artist_id = excluded.album_artist_id, track_number = excluded.track_number, \
                 disc_number = excluded.disc_number, year = excluded.year, genre = excluded.genre, \
                 duration_ms = excluded.duration_ms, format = excluded.format, \
                 bitrate_kbps = excluded.bitrate_kbps, size_bytes = excluded.size_bytes, \
                 mtime_ms = excluded.mtime_ms, has_embedded_cover = excluded.has_embedded_cover, \
                 has_embedded_lyrics = excluded.has_embedded_lyrics, has_cover = excluded.has_cover, \
                 has_lyrics = excluded.has_lyrics, search_text = excluded.search_text, \
                 updated_at = excluded.updated_at",
            )
            .bind(&t.id)
            .bind(&record.path)
            .bind(&t.title)
            .bind(&t.artist)
            .bind(&t.artist_id)
            .bind(&t.album)
            .bind(&t.album_id)
            .bind(&t.album_artist)
            .bind(&record.album_artist_id)
            .bind(t.track_number)
            .bind(t.disc_number)
            .bind(t.year)
            .bind(&t.genre)
            .bind(t.duration_ms)
            .bind(&t.format)
            .bind(t.bitrate_kbps)
            .bind(t.size_bytes)
            .bind(record.mtime_ms)
            .bind(record.has_embedded_cover)
            .bind(record.has_embedded_lyrics)
            .bind(t.has_cover)
            .bind(t.has_lyrics)
            .bind(&record.search_text)
            .bind(now_ms)
            .execute(&mut *tx)
            .await?;
            sqlx::query("DELETE FROM tombstones WHERE track_id = ?1").bind(&t.id).execute(&mut *tx).await?;
            sqlx::query("DELETE FROM waveforms WHERE track_id = ?1").bind(&t.id).execute(&mut *tx).await?;
        }
        for flags in &changes.flag_updates {
            sqlx::query("UPDATE tracks SET has_cover = ?2, has_lyrics = ?3, updated_at = ?4 WHERE id = ?1")
                .bind(&flags.id)
                .bind(flags.has_cover)
                .bind(flags.has_lyrics)
                .bind(now_ms)
                .execute(&mut *tx)
                .await?;
        }
        for id in &changes.removed {
            sqlx::query("DELETE FROM tracks WHERE id = ?1").bind(id).execute(&mut *tx).await?;
            sqlx::query("DELETE FROM waveforms WHERE track_id = ?1").bind(id).execute(&mut *tx).await?;
            sqlx::query("INSERT OR REPLACE INTO tombstones (track_id, removed_at) VALUES (?1, ?2)")
                .bind(id)
                .bind(now_ms)
                .execute(&mut *tx)
                .await?;
        }
        tx.commit().await?;
        Ok(())
    }
}

impl WaveformCache for SqliteStore {
    async fn cached_waveform(&self, track_id: &str) -> Result<Option<Vec<f32>>> {
        let raw: Option<String> = sqlx::query_scalar("SELECT peaks FROM waveforms WHERE track_id = ?1")
            .bind(track_id)
            .fetch_optional(&self.pool)
            .await?;
        Ok(raw.and_then(|json| serde_json::from_str(&json).ok()))
    }

    async fn store_waveform(&self, track_id: &str, peaks: &[f32]) -> Result<()> {
        sqlx::query("INSERT OR REPLACE INTO waveforms (track_id, peaks) VALUES (?1, ?2)")
            .bind(track_id)
            .bind(serde_json::to_string(peaks)?)
            .execute(&self.pool)
            .await?;
        Ok(())
    }
}
