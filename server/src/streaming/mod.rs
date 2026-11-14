//! Streaming: original files, cached opus/flac transcodes and waveform peaks.

use std::collections::HashMap;
use std::future::Future;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use anyhow::{Context, Result};

pub const WAVEFORM_PEAKS: usize = 120;
pub const OPUS_BITRATES: &[u32] = &[64, 96, 128, 192];
pub const DEFAULT_OPUS_BITRATE: u32 = 128;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StreamFormat {
    Original,
    Opus,
    /// Lossless FLAC transcode, for sources clients cannot decode (Apple Lossless in `.m4a`).
    Flac,
}

impl StreamFormat {
    pub fn parse(value: Option<&str>) -> Option<Self> {
        match value.unwrap_or("original") {
            "original" => Some(Self::Original),
            "opus" => Some(Self::Opus),
            "flac" => Some(Self::Flac),
            _ => None,
        }
    }
}

pub fn parse_bitrate(value: Option<&str>) -> Option<u32> {
    match value {
        None => Some(DEFAULT_OPUS_BITRATE),
        Some(v) => v.parse().ok().filter(|b| OPUS_BITRATES.contains(b)),
    }
}

/// Content type of an original file by its format (extension).
pub fn content_type(format: &str) -> &'static str {
    match format {
        "mp3" => "audio/mpeg",
        "flac" => "audio/flac",
        "ogg" | "opus" => "audio/ogg",
        "m4a" => "audio/mp4",
        "aac" => "audio/aac",
        "wav" => "audio/wav",
        _ => "application/octet-stream",
    }
}

/// Output of a transcode.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Target {
    Opus { bitrate_kbps: u32 },
    Flac,
}

impl Target {
    /// Cache path relative to the transcode cache dir.
    fn cache_path(self, track_id: &str) -> PathBuf {
        match self {
            Self::Opus { bitrate_kbps } => PathBuf::from("opus").join(format!("{track_id}-{bitrate_kbps}.ogg")),
            Self::Flac => PathBuf::from("flac").join(format!("{track_id}.flac")),
        }
    }

    pub fn content_type(self) -> &'static str {
        match self {
            Self::Opus { .. } => "audio/ogg",
            Self::Flac => "audio/flac",
        }
    }
}

/// Port: transcodes a file (blocking).
pub trait Transcoder: Send + Sync + 'static {
    fn transcode(&self, input: &Path, output: &Path, target: Target) -> Result<()>;
}

/// Port: decodes a file and returns raw per-chunk peak amplitudes (blocking).
pub trait WaveformAnalyzer: Send + Sync + 'static {
    fn raw_peaks(&self, path: &Path) -> Result<Vec<f32>>;
}

/// Port: persistent waveform cache.
pub trait WaveformCache: Send + Sync {
    fn cached_waveform(&self, track_id: &str) -> impl Future<Output = Result<Option<Vec<f32>>>> + Send;
    fn store_waveform(&self, track_id: &str, peaks: &[f32]) -> impl Future<Output = Result<()>> + Send;
}

/// Reduces raw peaks to `buckets` maxima normalized to 0..1.
pub fn normalize_peaks(raw: &[f32], buckets: usize) -> Vec<f32> {
    if raw.is_empty() {
        return vec![0.0; buckets];
    }
    let len = raw.len();
    let mut out: Vec<f32> = (0..buckets)
        .map(|i| {
            let start = (i * len / buckets).min(len - 1);
            let end = ((i + 1) * len / buckets).clamp(start + 1, len);
            raw[start..end].iter().fold(0.0f32, |m, v| m.max(v.abs()))
        })
        .collect();
    let max = out.iter().cloned().fold(0.0f32, f32::max);
    for v in &mut out {
        *v = if max > 0.0 && v.is_finite() { (*v / max).clamp(0.0, 1.0) } else { 0.0 };
    }
    out
}

/// Transcode cache under `{data}/cache`: `opus/{id}-{bitrate}.ogg` and `flac/{id}.flac`.
///
/// Each (track, target) is transcoded once at a time; output is written to a
/// temp file and renamed, so readers never see a partial file.
pub struct TranscodeCache {
    dir: PathBuf,
    transcoder: Arc<dyn Transcoder>,
    locks: Mutex<HashMap<String, Arc<tokio::sync::Mutex<()>>>>,
}

impl TranscodeCache {
    pub fn new(dir: PathBuf, transcoder: Arc<dyn Transcoder>) -> Self {
        Self { dir, transcoder, locks: Mutex::default() }
    }

    pub async fn get(&self, track_id: &str, source: &Path, output: Target) -> Result<PathBuf> {
        let target = self.dir.join(output.cache_path(track_id));
        let key = target.to_string_lossy().into_owned();
        let lock = {
            let mut locks = self.locks.lock().expect("transcode lock map poisoned");
            Arc::clone(locks.entry(key.clone()).or_default())
        };
        let _guard = lock.lock().await;
        if is_fresh(&target, source) {
            return Ok(target);
        }

        let dir = target.parent().expect("cache path has a parent");
        std::fs::create_dir_all(dir).with_context(|| format!("create {}", dir.display()))?;
        let name = target.file_name().expect("cache path has a file name").to_string_lossy();
        let temp = dir.join(format!(".{name}.{}.tmp", uuid::Uuid::new_v4().simple()));
        let transcoder = Arc::clone(&self.transcoder);
        let (src, tmp) = (source.to_path_buf(), temp.clone());
        let result = tokio::task::spawn_blocking(move || transcoder.transcode(&src, &tmp, output))
            .await
            .context("transcode task panicked")?;
        if let Err(err) = result.and_then(|_| std::fs::rename(&temp, &target).context("rename transcode")) {
            let _ = std::fs::remove_file(&temp);
            return Err(err);
        }
        Ok(target)
    }
}

fn is_fresh(cached: &Path, source: &Path) -> bool {
    let modified = |p: &Path| std::fs::metadata(p).and_then(|m| m.modified()).ok();
    match (modified(cached), modified(source)) {
        (Some(cached), Some(source)) => cached >= source,
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_into_buckets() {
        let raw: Vec<f32> = (0..1000).map(|i| (i as f32) / 2000.0).collect();
        let peaks = normalize_peaks(&raw, WAVEFORM_PEAKS);
        assert_eq!(peaks.len(), WAVEFORM_PEAKS);
        assert!(peaks.iter().all(|p| (0.0..=1.0).contains(p)));
        assert_eq!(*peaks.last().unwrap(), 1.0);
        assert_eq!(normalize_peaks(&[0.5; 3], 120).len(), 120);
        assert_eq!(normalize_peaks(&[], 120), vec![0.0; 120]);
    }

    #[test]
    fn validates_query_values() {
        assert_eq!(StreamFormat::parse(None), Some(StreamFormat::Original));
        assert_eq!(StreamFormat::parse(Some("flac")), Some(StreamFormat::Flac));
        assert_eq!(StreamFormat::parse(Some("mp3")), None);
        assert_eq!(parse_bitrate(Some("96")), Some(96));
        assert_eq!(parse_bitrate(Some("100")), None);
    }
}
