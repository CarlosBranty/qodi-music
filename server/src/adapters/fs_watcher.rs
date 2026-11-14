//! Debounced filesystem watcher for the music dir.
//!
//! Access events (opens/reads, e.g. while streaming or scanning) are ignored;
//! only creations, modifications and removals schedule a rescan.

use std::path::Path;
use std::time::Duration;

use anyhow::Result;
use notify::{Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use tokio::sync::mpsc;

pub type MusicWatcher = RecommendedWatcher;

/// Returns `true` for events that can change the library.
pub fn is_relevant(kind: &EventKind) -> bool {
    matches!(kind, EventKind::Create(_) | EventKind::Modify(_) | EventKind::Remove(_) | EventKind::Any)
}

/// Calls `on_change` once changes have settled for `debounce`. Must be called inside a
/// tokio runtime. Keep the returned watcher alive for as long as events are wanted.
pub fn watch(dir: &Path, debounce: Duration, on_change: impl Fn() + Send + 'static) -> Result<MusicWatcher> {
    let (tx, mut rx) = mpsc::unbounded_channel::<()>();
    let mut watcher = notify::recommended_watcher(move |result: notify::Result<Event>| match result {
        Ok(event) if is_relevant(&event.kind) => {
            let _ = tx.send(());
        }
        Ok(_) => {}
        Err(err) => tracing::warn!(error = %err, "filesystem watcher error"),
    })?;
    watcher.watch(dir, RecursiveMode::Recursive)?;

    tokio::spawn(async move {
        while rx.recv().await.is_some() {
            // Wait until no new event arrives for `debounce`.
            loop {
                match tokio::time::timeout(debounce, rx.recv()).await {
                    Ok(Some(())) => continue,
                    Ok(None) => return,
                    Err(_) => break,
                }
            }
            on_change();
        }
    });
    Ok(watcher)
}

#[cfg(test)]
mod tests {
    use notify::event::{AccessKind, CreateKind};

    use super::*;

    #[test]
    fn ignores_access_events() {
        assert!(!is_relevant(&EventKind::Access(AccessKind::Any)));
        assert!(is_relevant(&EventKind::Create(CreateKind::File)));
    }
}
