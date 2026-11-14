//! Library: the catalog of tracks, albums and artists built by scanning the music dir.

pub mod ids;
pub mod scanner;

use std::future::Future;
use std::path::{Path, PathBuf};

use serde::Serialize;

pub const SUPPORTED_EXTENSIONS: &[&str] = &["mp3", "flac", "ogg", "opus", "m4a", "aac", "wav"];
pub const UNKNOWN_ARTIST: &str = "Unknown Artist";
pub const UNKNOWN_ALBUM: &str = "Unknown Album";
/// Sidecar cover file names, in priority order (matched case-insensitively).
pub const SIDECAR_COVERS: &[&str] = &["cover.jpg", "folder.jpg", "cover.png"];

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct Track {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub artist_id: String,
    pub album: String,
    pub album_id: String,
    pub album_artist: String,
    pub track_number: Option<i64>,
    pub disc_number: Option<i64>,
    pub year: Option<i64>,
    pub genre: Option<String>,
    pub duration_ms: i64,
    pub format: String,
    pub bitrate_kbps: Option<i64>,
    pub sample_rate_hz: Option<i64>,
    /// `None` for lossy codecs.
    pub bit_depth: Option<i64>,
    pub channels: Option<i64>,
    pub lossless: bool,
    pub size_bytes: i64,
    pub has_cover: bool,
    pub has_lyrics: bool,
    pub favorite: bool,
    #[serde(serialize_with = "crate::time::serialize_ms")]
    pub updated_at: i64,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct Album {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub artist_id: String,
    pub year: Option<i64>,
    pub track_count: i64,
    pub duration_ms: i64,
    pub cover_track_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct Artist {
    pub id: String,
    pub name: String,
    pub album_count: i64,
    pub track_count: i64,
}

/// Where a track's bytes live, for streaming, covers, lyrics and waveforms.
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct TrackFile {
    pub id: String,
    /// Path relative to the music dir, forward slashes.
    pub path: String,
    pub format: String,
}

/// Raw metadata read from a file's tags and audio properties.
#[derive(Debug, Clone, Default)]
pub struct TrackMeta {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub album_artist: Option<String>,
    pub track_number: Option<i64>,
    pub disc_number: Option<i64>,
    pub year: Option<i64>,
    pub genre: Option<String>,
    pub duration_ms: i64,
    pub bitrate_kbps: Option<i64>,
    pub sample_rate_hz: Option<i64>,
    pub bit_depth: Option<i64>,
    pub channels: Option<i64>,
    /// Codec-level answer when the file could be parsed; `None` falls back to the extension.
    pub lossless: Option<bool>,
    pub has_embedded_cover: bool,
    pub has_embedded_lyrics: bool,
}

#[derive(Debug, Clone)]
pub struct Cover {
    pub data: Vec<u8>,
    pub mime: String,
}

/// Port: reads tags, embedded art and embedded lyrics from audio files (blocking).
pub trait TagReader: Send + Sync + 'static {
    fn read(&self, path: &Path) -> anyhow::Result<TrackMeta>;
    fn embedded_cover(&self, path: &Path) -> Option<Cover>;
    fn embedded_lyrics(&self, path: &Path) -> Option<String>;
}

/// A fully resolved track as persisted by the scanner.
#[derive(Debug, Clone)]
pub struct TrackRecord {
    pub track: Track,
    pub path: String,
    pub album_artist_id: String,
    pub mtime_ms: i64,
    pub has_embedded_cover: bool,
    pub has_embedded_lyrics: bool,
    pub search_text: String,
}

#[derive(Debug, Clone, Copy)]
pub struct FileFacts {
    pub size_bytes: i64,
    pub mtime_ms: i64,
    pub has_sidecar_cover: bool,
    pub has_sidecar_lyrics: bool,
}

#[derive(Debug, Clone, Default)]
pub struct TrackFilter {
    /// Case-insensitive substring over title/artist/album.
    pub query: Option<String>,
    pub artist_id: Option<String>,
    pub album_id: Option<String>,
}

#[derive(Debug, Clone, Copy)]
pub struct Page {
    pub limit: i64,
    pub offset: i64,
}

impl Page {
    pub const DEFAULT_LIMIT: i64 = 100;
    pub const MAX_LIMIT: i64 = 1000;
    pub const ALL: Page = Page { limit: i64::MAX, offset: 0 };

    pub fn new(limit: Option<u32>, offset: Option<u32>) -> Self {
        Self {
            limit: limit.map_or(Self::DEFAULT_LIMIT, |l| (l as i64).min(Self::MAX_LIMIT)),
            offset: offset.unwrap_or(0) as i64,
        }
    }
}

/// Port: read side of the catalog. All track reads are scoped to a user (for `favorite`).
pub trait LibraryCatalog: Send + Sync {
    fn tracks(
        &self,
        user_id: &str,
        filter: &TrackFilter,
        page: Page,
    ) -> impl Future<Output = anyhow::Result<(Vec<Track>, i64)>> + Send;
    fn track(&self, user_id: &str, id: &str) -> impl Future<Output = anyhow::Result<Option<Track>>> + Send;
    fn track_file(&self, id: &str) -> impl Future<Output = anyhow::Result<Option<TrackFile>>> + Send;
    fn albums(
        &self,
        artist_id: Option<&str>,
        page: Page,
    ) -> impl Future<Output = anyhow::Result<(Vec<Album>, i64)>> + Send;
    fn album(&self, id: &str) -> impl Future<Output = anyhow::Result<Option<Album>>> + Send;
    fn artists(&self, page: Page) -> impl Future<Output = anyhow::Result<(Vec<Artist>, i64)>> + Send;
    /// Tracks updated after `since` and ids removed after `since` (`None` = full snapshot).
    fn changes(
        &self,
        user_id: &str,
        since_ms: Option<i64>,
    ) -> impl Future<Output = anyhow::Result<(Vec<Track>, Vec<String>)>> + Send;
}

/// Extensions that are always lossless. `m4a` depends on the codec (ALAC vs AAC).
pub const LOSSLESS_EXTENSIONS: &[&str] = &["flac", "wav", "aiff", "aif", "ape", "wv"];

pub fn extension_of(path: &Path) -> Option<String> {
    path.extension().and_then(|e| e.to_str()).map(str::to_ascii_lowercase)
}

pub fn is_supported(path: &Path) -> bool {
    extension_of(path).is_some_and(|ext| SUPPORTED_EXTENSIONS.contains(&ext.as_str()))
}

/// Finds `cover.jpg`/`folder.jpg`/`cover.png` (case-insensitive) in `dir`.
pub fn find_sidecar_cover(dir: &Path) -> Option<PathBuf> {
    let names: Vec<(String, PathBuf)> = std::fs::read_dir(dir)
        .ok()?
        .filter_map(Result::ok)
        .filter_map(|e| Some((e.file_name().to_str()?.to_ascii_lowercase(), e.path())))
        .collect();
    SIDECAR_COVERS
        .iter()
        .find_map(|wanted| names.iter().find(|(name, _)| name == wanted).map(|(_, p)| p.clone()))
        .filter(|p| p.is_file())
}

/// `<dir>/<stem>.lrc` next to the audio file.
pub fn sidecar_lyrics_path(audio: &Path) -> PathBuf {
    audio.with_extension("lrc")
}

pub fn mime_for_image_path(path: &Path) -> &'static str {
    match extension_of(path).as_deref() {
        Some("png") => "image/png",
        _ => "image/jpeg",
    }
}

fn clean(value: Option<String>) -> Option<String> {
    value.map(|v| v.trim().to_string()).filter(|v| !v.is_empty())
}

/// Applies the contract fallbacks (title = file stem, artist = `Unknown Artist`,
/// album = parent folder name) and derives ids.
pub fn build_record(relative_path: &str, facts: FileFacts, meta: TrackMeta) -> TrackRecord {
    let path = Path::new(relative_path);
    let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or(relative_path).to_string();
    let parent = relative_path
        .rsplit_once('/')
        .and_then(|(dir, _)| dir.rsplit('/').next())
        .filter(|s| !s.is_empty())
        .unwrap_or(UNKNOWN_ALBUM)
        .to_string();

    let title = clean(meta.title).unwrap_or(stem);
    let artist = clean(meta.artist).unwrap_or_else(|| UNKNOWN_ARTIST.to_string());
    let album = clean(meta.album).unwrap_or(parent);
    let album_artist = clean(meta.album_artist).unwrap_or_else(|| artist.clone());
    let search_text = format!("{title}\n{artist}\n{album}").to_lowercase();
    let format = extension_of(path).unwrap_or_default();
    let lossless = meta.lossless.unwrap_or_else(|| LOSSLESS_EXTENSIONS.contains(&format.as_str()));

    let track = Track {
        id: ids::track_id(relative_path),
        artist_id: ids::artist_id(&artist),
        album_id: ids::album_id(&album_artist, &album),
        title,
        artist,
        album,
        album_artist: album_artist.clone(),
        track_number: meta.track_number,
        disc_number: meta.disc_number,
        year: meta.year,
        genre: clean(meta.genre),
        duration_ms: meta.duration_ms,
        format,
        bitrate_kbps: meta.bitrate_kbps,
        sample_rate_hz: meta.sample_rate_hz,
        bit_depth: meta.bit_depth.filter(|_| lossless),
        channels: meta.channels,
        lossless,
        size_bytes: facts.size_bytes,
        has_cover: meta.has_embedded_cover || facts.has_sidecar_cover,
        has_lyrics: meta.has_embedded_lyrics || facts.has_sidecar_lyrics,
        favorite: false,
        updated_at: 0,
    };
    TrackRecord {
        album_artist_id: ids::artist_id(&album_artist),
        track,
        path: relative_path.to_string(),
        mtime_ms: facts.mtime_ms,
        has_embedded_cover: meta.has_embedded_cover,
        has_embedded_lyrics: meta.has_embedded_lyrics,
        search_text,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fallbacks_apply_when_tags_missing() {
        let facts = FileFacts { size_bytes: 1, mtime_ms: 1, has_sidecar_cover: false, has_sidecar_lyrics: false };
        let record = build_record("Some Folder/my song.flac", facts, TrackMeta::default());
        assert_eq!(record.track.title, "my song");
        assert_eq!(record.track.artist, UNKNOWN_ARTIST);
        assert_eq!(record.track.album, "Some Folder");
        assert_eq!(record.track.format, "flac");
        let root = build_record("loose.mp3", facts, TrackMeta::default());
        assert_eq!(root.track.album, UNKNOWN_ALBUM);
        assert!(!root.track.lossless);
        assert!(record.track.lossless, "flac falls back to lossless when the codec is unknown");
        let lossy = TrackMeta { bit_depth: Some(16), lossless: Some(false), ..TrackMeta::default() };
        assert_eq!(build_record("a.m4a", facts, lossy).track.bit_depth, None);
    }
}
