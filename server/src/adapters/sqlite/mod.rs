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
         t.bitrate_kbps, t.sample_rate_hz, t.bit_depth, t.channels, t.lossless, t.size_bytes, t.has_cover, t.has_lyrics, t.updated_at, \
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
        let migrator = sqlx::migrate!("./migrations");
        repair_first_release(&pool, &migrator).await.context("repair first-release schema")?;
        migrator.run(&pool).await.context("run migrations")?;
        Ok(Self { pool })
    }
}

/// SHA-384 of `0001_init.sql` as shipped by the first release (commit 1f7bdf4).
/// That file was later edited in place to key `plays` by `(user_id, client_id)`.
const FIRST_RELEASE_0001_CHECKSUM: &str =
    "6686589a6753c77f2ec6e98c197a718ce9329fc0ac274ac59f311eae2e6540d0bf58e7f8190080bf40ee4e54fcc1f312";

/// A database created by the first release fails sqlx's checksum check for
/// migration 1. Rebuild its `plays` table with the current key (keeping every row)
/// and record the current checksum, in one transaction. No-op for any other database.
async fn repair_first_release(pool: &SqlitePool, migrator: &sqlx::migrate::Migrator) -> Result<()> {
    let has_table: bool =
        sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = '_sqlx_migrations')")
            .fetch_one(pool)
            .await?;
    if !has_table {
        return Ok(());
    }
    let applied: Option<Vec<u8>> = sqlx::query_scalar("SELECT checksum FROM _sqlx_migrations WHERE version = 1")
        .fetch_optional(pool)
        .await?;
    if applied.as_deref().map(hex::encode).as_deref() != Some(FIRST_RELEASE_0001_CHECKSUM) {
        return Ok(());
    }
    let current = migrator
        .iter()
        .find(|m| m.version == 1)
        .context("embedded migration 1 missing")?
        .checksum
        .to_vec();
    let mut tx = pool.begin_with("BEGIN IMMEDIATE").await?;
    for statement in [
        "CREATE TABLE plays_repaired (\
             client_id TEXT NOT NULL, \
             user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE, \
             track_id TEXT NOT NULL, played_at INTEGER NOT NULL, listened_ms INTEGER NOT NULL, \
             PRIMARY KEY (user_id, client_id))",
        "INSERT INTO plays_repaired (client_id, user_id, track_id, played_at, listened_ms) \
             SELECT client_id, user_id, track_id, played_at, listened_ms FROM plays",
        "DROP TABLE plays",
        "ALTER TABLE plays_repaired RENAME TO plays",
        "CREATE INDEX plays_user_time ON plays (user_id, played_at)",
    ] {
        sqlx::query(statement).execute(&mut *tx).await?;
    }
    sqlx::query("UPDATE _sqlx_migrations SET checksum = ?1 WHERE version = 1").bind(current).execute(&mut *tx).await?;
    tx.commit().await?;
    tracing::info!("repaired plays table of a first-release database");
    Ok(())
}
