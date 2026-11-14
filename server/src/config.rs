//! Server configuration read from `QODI_*` environment variables (see `docs/api.md`).

use std::path::PathBuf;

use anyhow::{Context, Result};

#[derive(Clone)]
pub struct Config {
    pub bind: String,
    pub music_dir: PathBuf,
    pub data_dir: PathBuf,
    pub web_dir: PathBuf,
    /// Published client builds (`android/latest.json` and the APK).
    pub dist_dir: PathBuf,
    pub jwt_secret: Option<String>,
    pub token_ttl_days: i64,
    pub admin_user: Option<String>,
    pub admin_password: Option<String>,
    /// Periodic full rescan interval; `0` disables it.
    pub scan_interval_secs: u64,
    /// ffmpeg binary used for opus transcoding.
    pub ffmpeg: String,
}

impl Config {
    /// Defaults from the contract, rooted at the given music and data directories.
    pub fn new(music_dir: impl Into<PathBuf>, data_dir: impl Into<PathBuf>) -> Self {
        Self {
            bind: "0.0.0.0:4040".into(),
            music_dir: music_dir.into(),
            data_dir: data_dir.into(),
            web_dir: PathBuf::from("/app/web"),
            dist_dir: PathBuf::from("/app/dist"),
            jwt_secret: None,
            token_ttl_days: 30,
            admin_user: None,
            admin_password: None,
            scan_interval_secs: 3600,
            ffmpeg: "ffmpeg".into(),
        }
    }

    pub fn from_env() -> Result<Self> {
        let mut config = Self::new(
            env("QODI_MUSIC_DIR").unwrap_or_else(|| "/music".into()),
            env("QODI_DATA_DIR").unwrap_or_else(|| "/data".into()),
        );
        if let Some(bind) = env("QODI_BIND") {
            config.bind = bind;
        }
        if let Some(web) = env("QODI_WEB_DIR") {
            config.web_dir = web.into();
        }
        if let Some(dist) = env("QODI_DIST_DIR") {
            config.dist_dir = dist.into();
        }
        config.jwt_secret = env("QODI_JWT_SECRET");
        if let Some(ttl) = env("QODI_TOKEN_TTL_DAYS") {
            config.token_ttl_days = ttl.parse().context("QODI_TOKEN_TTL_DAYS must be an integer")?;
        }
        config.admin_user = env("QODI_ADMIN_USER");
        config.admin_password = env("QODI_ADMIN_PASSWORD");
        if let Some(secs) = env("QODI_SCAN_INTERVAL_SECS") {
            config.scan_interval_secs =
                secs.parse().context("QODI_SCAN_INTERVAL_SECS must be an integer")?;
        }
        if let Some(ffmpeg) = env("QODI_FFMPEG") {
            config.ffmpeg = ffmpeg;
        }
        Ok(config)
    }
}

fn env(name: &str) -> Option<String> {
    std::env::var(name).ok().filter(|v| !v.trim().is_empty())
}
