//! Incremental library scanner.
//!
//! The filesystem walk and tag reading run on the blocking pool; only files whose
//! size or mtime changed are re-read, plus files indexed before the audio quality
//! fields existed (once, after upgrading). Files that disappeared become tombstones.
//! Scans are serialized: at most one runs and at most one more is queued.

use std::collections::{HashMap, HashSet};
use std::fs;
use std::future::Future;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::UNIX_EPOCH;

use anyhow::{Context, Result};
use tokio::sync::Mutex;

use super::{FileFacts, TagReader, TrackRecord, build_record, find_sidecar_cover, ids, is_supported, sidecar_lyrics_path};
use crate::time::now_ms;

const MAX_DEPTH: usize = 32;

/// What the index currently knows about a file, keyed by relative path.
#[derive(Debug, Clone)]
pub struct IndexedFile {
    pub id: String,
    pub size_bytes: i64,
    pub mtime_ms: i64,
    pub has_embedded_cover: bool,
    pub has_embedded_lyrics: bool,
    pub has_cover: bool,
    pub has_lyrics: bool,
    /// `false` for rows indexed before quality fields existed.
    pub quality_scanned: bool,
}

#[derive(Debug, Clone)]
pub struct FlagUpdate {
    pub id: String,
    pub has_cover: bool,
    pub has_lyrics: bool,
}

#[derive(Debug, Default)]
pub struct ScanChanges {
    pub upserts: Vec<TrackRecord>,
    /// Unchanged audio whose sidecar cover/lyrics appeared or disappeared.
    pub flag_updates: Vec<FlagUpdate>,
    pub removed: Vec<String>,
    pub unchanged: usize,
}

#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct ScanReport {
    pub upserted: usize,
    pub flags_updated: usize,
    pub removed: usize,
    pub unchanged: usize,
}

/// Port: the persistent index the scanner reconciles against.
pub trait LibraryIndex: Clone + Send + Sync + 'static {
    fn snapshot(&self) -> impl Future<Output = Result<HashMap<String, IndexedFile>>> + Send;
    fn apply(&self, changes: &ScanChanges, now_ms: i64) -> impl Future<Output = Result<()>> + Send;
}

pub struct Scanner<I: LibraryIndex> {
    index: I,
    tags: Arc<dyn TagReader>,
    music_dir: PathBuf,
    running: Mutex<()>,
    queued: AtomicBool,
}

impl<I: LibraryIndex> Scanner<I> {
    pub fn new(index: I, tags: Arc<dyn TagReader>, music_dir: PathBuf) -> Self {
        Self { index, tags, music_dir, running: Mutex::new(()), queued: AtomicBool::new(false) }
    }

    /// Runs a scan now and waits for it (waits for any running scan first).
    pub async fn scan_now(&self) -> Result<ScanReport> {
        let _guard = self.running.lock().await;
        self.run().await
    }

    /// Schedules a background scan. Requests made while one is already queued are coalesced.
    pub fn request(self: &Arc<Self>) {
        if self.queued.swap(true, Ordering::SeqCst) {
            return;
        }
        let this = Arc::clone(self);
        tokio::spawn(async move {
            let _guard = this.running.lock().await;
            this.queued.store(false, Ordering::SeqCst);
            if let Err(err) = this.run().await {
                tracing::error!(error = %format!("{err:#}"), "library scan failed");
            }
        });
    }

    async fn run(&self) -> Result<ScanReport> {
        let started = std::time::Instant::now();
        let snapshot = self.index.snapshot().await?;
        let tags = Arc::clone(&self.tags);
        let root = self.music_dir.clone();
        let changes = tokio::task::spawn_blocking(move || diff_library(&root, &snapshot, tags.as_ref()))
            .await
            .context("scan task panicked")??;
        self.index.apply(&changes, now_ms()).await?;
        let report = ScanReport {
            upserted: changes.upserts.len(),
            flags_updated: changes.flag_updates.len(),
            removed: changes.removed.len(),
            unchanged: changes.unchanged,
        };
        tracing::info!(?report, elapsed_ms = started.elapsed().as_millis() as u64, "library scan finished");
        Ok(report)
    }
}

struct FoundFile {
    absolute: PathBuf,
    relative: String,
    size_bytes: i64,
    mtime_ms: i64,
}

/// Walks the music dir and computes the changes against the index snapshot (blocking).
pub fn diff_library(
    root: &Path,
    snapshot: &HashMap<String, IndexedFile>,
    tags: &dyn TagReader,
) -> Result<ScanChanges> {
    // Refuse to scan an unreadable root: that would tombstone the whole library
    // (e.g. a network mount that is not up yet).
    fs::read_dir(root).with_context(|| format!("music dir {} is not readable", root.display()))?;

    let mut files = Vec::new();
    let mut unreadable = Vec::new();
    walk(root, root, 0, &mut files, &mut unreadable);

    let mut changes = ScanChanges::default();
    let mut seen = HashSet::new();
    let mut cover_cache: HashMap<PathBuf, bool> = HashMap::new();

    for file in files {
        seen.insert(file.relative.clone());
        let dir = file.absolute.parent().unwrap_or(root).to_path_buf();
        let has_sidecar_cover =
            *cover_cache.entry(dir.clone()).or_insert_with(|| find_sidecar_cover(&dir).is_some());
        let has_sidecar_lyrics = sidecar_lyrics_path(&file.absolute).is_file();

        match snapshot.get(&file.relative) {
            Some(known)
                if known.quality_scanned && known.size_bytes == file.size_bytes && known.mtime_ms == file.mtime_ms =>
            {
                let has_cover = known.has_embedded_cover || has_sidecar_cover;
                let has_lyrics = known.has_embedded_lyrics || has_sidecar_lyrics;
                if has_cover != known.has_cover || has_lyrics != known.has_lyrics {
                    changes.flag_updates.push(FlagUpdate { id: known.id.clone(), has_cover, has_lyrics });
                } else {
                    changes.unchanged += 1;
                }
            }
            _ => {
                let meta = tags.read(&file.absolute).unwrap_or_else(|err| {
                    tracing::warn!(path = %file.relative, error = %err, "could not read tags");
                    Default::default()
                });
                let facts = FileFacts {
                    size_bytes: file.size_bytes,
                    mtime_ms: file.mtime_ms,
                    has_sidecar_cover,
                    has_sidecar_lyrics,
                };
                changes.upserts.push(build_record(&file.relative, facts, meta));
            }
        }
    }

    for (path, known) in snapshot {
        let under_unreadable = unreadable.iter().any(|prefix: &String| path.starts_with(prefix.as_str()));
        if !seen.contains(path) && !under_unreadable {
            changes.removed.push(known.id.clone());
        }
    }
    debug_assert!(changes.upserts.iter().all(|r| r.track.id == ids::track_id(&r.path)));
    Ok(changes)
}

fn walk(root: &Path, dir: &Path, depth: usize, out: &mut Vec<FoundFile>, unreadable: &mut Vec<String>) {
    let relative_dir = relative(root, dir).unwrap_or_default();
    let prefix = if relative_dir.is_empty() { String::new() } else { format!("{relative_dir}/") };
    if depth > MAX_DEPTH {
        tracing::warn!(dir = %dir.display(), "directory nesting too deep, skipping");
        unreadable.push(prefix);
        return;
    }
    let entries = match fs::read_dir(dir) {
        Ok(entries) => entries,
        Err(err) => {
            tracing::warn!(dir = %dir.display(), error = %err, "cannot read directory");
            unreadable.push(prefix);
            return;
        }
    };
    for entry in entries.filter_map(Result::ok) {
        let name = entry.file_name();
        let Some(name) = name.to_str() else {
            tracing::warn!(path = %entry.path().display(), "skipping non UTF-8 path");
            continue;
        };
        // Hidden entries include Syncthing's `.stfolder`, `.stversions` and temp files.
        if name.starts_with('.') {
            continue;
        }
        let path = entry.path();
        let Ok(meta) = fs::metadata(&path) else { continue };
        if meta.is_dir() {
            walk(root, &path, depth + 1, out, unreadable);
        } else if meta.is_file() && is_supported(&path) {
            let Some(relative) = relative(root, &path) else { continue };
            let mtime_ms = meta
                .modified()
                .ok()
                .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
                .map_or(0, |d| d.as_millis() as i64);
            out.push(FoundFile { absolute: path, relative, size_bytes: meta.len() as i64, mtime_ms });
        }
    }
}

/// Relative path with forward slashes, or `None` for non UTF-8 components.
fn relative(root: &Path, path: &Path) -> Option<String> {
    let rel = path.strip_prefix(root).ok()?;
    let parts: Option<Vec<&str>> = rel.components().map(|c| c.as_os_str().to_str()).collect();
    Some(parts?.join("/"))
}
