//! Stable identifiers, derived exactly as specified in `docs/api.md`.

use sha2::{Digest, Sha256};

fn short_hash(input: &str) -> String {
    let digest = Sha256::digest(input.as_bytes());
    let mut hex = hex::encode(digest);
    hex.truncate(16);
    hex
}

/// First 16 hex chars of SHA-256 of the path relative to the music dir (forward slashes).
pub fn track_id(relative_path: &str) -> String {
    short_hash(relative_path)
}

/// First 16 hex chars of SHA-256 of `lower(album_artist) + "\0" + lower(album)`.
pub fn album_id(album_artist: &str, album: &str) -> String {
    short_hash(&format!("{}\u{0}{}", album_artist.to_lowercase(), album.to_lowercase()))
}

/// First 16 hex chars of SHA-256 of `lower(artist)`.
pub fn artist_id(artist: &str) -> String {
    short_hash(&artist.to_lowercase())
}
