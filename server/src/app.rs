//! Composition root: wires adapters into the feature services and the HTTP router.

use std::ops::Deref;
use std::sync::Arc;
use std::time::Duration;

use anyhow::{Context, Result};
use axum::Router;

use crate::adapters::ffmpeg::FfmpegTranscoder;
use crate::adapters::fs_watcher::{self, MusicWatcher};
use crate::adapters::lofty_tags::LoftyTagReader;
use crate::adapters::sqlite::SqliteStore;
use crate::adapters::symphonia_waveform::SymphoniaWaveform;
use crate::auth::{TokenService, UserRepository, hash_password, load_or_create_secret};
use crate::config::Config;
use crate::library::TagReader;
use crate::library::scanner::Scanner;
use crate::streaming::{OpusCache, WaveformAnalyzer};
use crate::time::now_ms;

pub struct AppInner {
    pub config: Config,
    pub store: SqliteStore,
    pub tokens: TokenService,
    pub scanner: Arc<Scanner<SqliteStore>>,
    pub tags: Arc<dyn TagReader>,
    pub waveform: Arc<dyn WaveformAnalyzer>,
    pub opus: OpusCache,
}

#[derive(Clone)]
pub struct AppState(Arc<AppInner>);

impl Deref for AppState {
    type Target = AppInner;

    fn deref(&self) -> &AppInner {
        &self.0
    }
}

pub struct App {
    pub state: AppState,
    pub router: Router,
}

/// Background jobs; dropping this stops the filesystem watcher.
pub struct Background {
    _watcher: Option<MusicWatcher>,
}

impl App {
    /// Creates data dirs, runs migrations, loads the JWT secret and bootstraps the admin user.
    pub async fn build(config: Config) -> Result<Self> {
        let opus_dir = config.data_dir.join("cache").join("opus");
        std::fs::create_dir_all(&opus_dir).with_context(|| format!("create {}", opus_dir.display()))?;

        let store = SqliteStore::open(&config.data_dir).await?;
        let secret = load_or_create_secret(&config.data_dir, config.jwt_secret.as_deref())?;
        let tokens = TokenService::new(&secret, config.token_ttl_days)?;
        bootstrap_admin(&store, &config).await?;

        let tags: Arc<dyn TagReader> = Arc::new(LoftyTagReader);
        let scanner = Arc::new(Scanner::new(store.clone(), tags.clone(), config.music_dir.clone()));
        let opus = OpusCache::new(opus_dir, Arc::new(FfmpegTranscoder::new(config.ffmpeg.clone())));
        let state = AppState(Arc::new(AppInner {
            config,
            store,
            tokens,
            scanner,
            tags,
            waveform: Arc::new(SymphoniaWaveform),
            opus,
        }));
        let router = crate::http::router(state.clone());
        Ok(Self { state, router })
    }

    /// Starts the initial scan, the periodic rescan and the debounced watcher.
    pub fn start_background(&self) -> Background {
        let scanner = self.state.scanner.clone();
        scanner.request();

        let interval = self.state.config.scan_interval_secs;
        if interval > 0 {
            let scanner = scanner.clone();
            tokio::spawn(async move {
                let mut ticker = tokio::time::interval(Duration::from_secs(interval));
                ticker.tick().await; // the first tick fires immediately; the initial scan covers it
                loop {
                    ticker.tick().await;
                    scanner.request();
                }
            });
        }

        let watched = scanner.clone();
        let watcher = fs_watcher::watch(&self.state.config.music_dir, Duration::from_secs(3), move || {
            watched.request();
        })
        .inspect_err(|err| tracing::warn!(error = %err, "filesystem watcher unavailable; relying on periodic scans"))
        .ok();
        Background { _watcher: watcher }
    }
}

async fn bootstrap_admin(store: &SqliteStore, config: &Config) -> Result<()> {
    let (Some(username), Some(password)) = (&config.admin_user, &config.admin_password) else {
        return Ok(());
    };
    if store.credentials(username).await?.is_some() {
        return Ok(());
    }
    let password = password.clone();
    let hash = tokio::task::spawn_blocking(move || hash_password(&password)).await??;
    store.create_user(username, &hash, now_ms()).await?;
    tracing::info!(%username, "created admin user");
    Ok(())
}
