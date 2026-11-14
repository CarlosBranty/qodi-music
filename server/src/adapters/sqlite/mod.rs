//! SQLite store implementing the repository ports of every feature.

use std::path::Path;
use std::str::FromStr;
use std::time::Duration;

use anyhow::{Context, Result};
use sqlx::SqlitePool;
use sqlx::sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions};

/// Track columns as exposed by the API. `?1` must be bound to the user id (for `favorite`).
macro_rules! track_columns {
    () => {
        "t.id, t.title, t.artist, t.artist_id, t.album, t.album_id, t.album_artist, \
         t.track_number, t.disc_number, t.year, t.genre, t.duration_ms, t.format, \
         t.bitrate_kbps, t.size_bytes, t.has_cover, t.has_lyrics, t.updated_at, \
         EXISTS(SELECT 1 FROM favorites f WHERE f.user_id = ?1 AND f.track_id = t.id) AS favorite"
    };
}

/// Contract track order: artist, album, disc, track, title.
macro_rules! track_order {
    () => {
        " ORDER BY t.artist COLLATE NOCASE, t.album COLLATE NOCASE, t.disc_number, \
          t.track_number, t.title COLLATE NOCASE, t.id"
    };
}

mod favorites;
mod library;
mod playlists;
mod stats;
mod users;

#[derive(Clone)]
pub struct SqliteStore {
    pool: SqlitePool,
}

impl SqliteStore {
    /// Opens (creating if needed) `{data}/qodi.db` and runs the embedded migrations.
    pub async fn open(data_dir: &Path) -> Result<Self> {
        let path = data_dir.join("qodi.db");
        let options = SqliteConnectOptions::from_str("sqlite://")?
            .filename(&path)
            .create_if_missing(true)
            .journal_mode(SqliteJournalMode::Wal)
            .foreign_keys(true)
            .busy_timeout(Duration::from_secs(10));
        let pool = SqlitePoolOptions::new()
            .max_connections(8)
            .connect_with(options)
            .await
            .with_context(|| format!("open database {}", path.display()))?;
        sqlx::migrate!("./migrations").run(&pool).await.context("run migrations")?;
        Ok(Self { pool })
    }
}
