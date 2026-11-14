//! Stats: play history and listening summaries.

use std::future::Future;

use serde::Serialize;

use crate::library::Track;

const DAY_MS: i64 = 86_400_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StatsRange {
    Days7,
    Days30,
    All,
}

impl StatsRange {
    pub fn parse(value: Option<&str>) -> Option<Self> {
        match value.unwrap_or("30d") {
            "7d" => Some(Self::Days7),
            "30d" => Some(Self::Days30),
            "all" => Some(Self::All),
            _ => None,
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Days7 => "7d",
            Self::Days30 => "30d",
            Self::All => "all",
        }
    }

    /// Lower bound (inclusive) of the range in epoch ms, `None` for all time.
    pub fn since_ms(self, now_ms: i64) -> Option<i64> {
        match self {
            Self::Days7 => Some(now_ms - 7 * DAY_MS),
            Self::Days30 => Some(now_ms - 30 * DAY_MS),
            Self::All => None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct PlayRecord {
    pub client_id: String,
    pub track_id: String,
    pub played_at_ms: i64,
    pub listened_ms: i64,
}

#[derive(Debug, Clone, Serialize)]
pub struct Summary {
    pub range: &'static str,
    pub total_plays: i64,
    pub total_listen_ms: i64,
    pub unique_tracks: i64,
    pub top_tracks: Vec<TopTrack>,
    pub top_artists: Vec<TopArtist>,
    pub daily: Vec<DailyListen>,
}

#[derive(Debug, Clone, Serialize)]
pub struct TopTrack {
    pub track: Track,
    pub plays: i64,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct TopArtist {
    pub artist_id: String,
    pub name: String,
    pub plays: i64,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct DailyListen {
    pub date: String,
    pub listen_ms: i64,
}

pub const TOP_LIMIT: i64 = 10;

/// Port: play log persistence and aggregation.
pub trait StatsRepository: Send + Sync {
    /// Inserts plays, ignoring duplicate `client_id`s; returns how many were new.
    fn record_plays(&self, user_id: &str, plays: &[PlayRecord]) -> impl Future<Output = anyhow::Result<u64>> + Send;
    fn summary(&self, user_id: &str, range: StatsRange, now_ms: i64)
    -> impl Future<Output = anyhow::Result<Summary>> + Send;
}
