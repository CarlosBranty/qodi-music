//! qodi-server: personal music streaming server.
//!
//! Modules are named by feature (`library`, `streaming`, `playlists`, `favorites`,
//! `stats`, `lyrics`, `auth`); each holds its domain types and ports. `adapters`
//! implements the ports (SQLite, lofty, symphonia, ffmpeg, notify) and `http`
//! exposes the API described in `docs/api.md`.

pub mod adapters;
pub mod app;
pub mod auth;
pub mod config;
pub mod favorites;
pub mod http;
pub mod library;
pub mod lyrics;
pub mod playlists;
pub mod stats;
pub mod streaming;
pub mod time;

pub use app::App;
pub use config::Config;
