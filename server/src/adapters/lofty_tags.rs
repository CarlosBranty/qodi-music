//! lofty-based tag reader.

use std::path::Path;

use anyhow::Result;
use lofty::picture::PictureType;
use lofty::prelude::*;
use lofty::tag::Tag;

use crate::library::{Cover, TagReader, TrackMeta};

pub struct LoftyTagReader;

/// Primary tag first, then the others (e.g. ID3v2 before ID3v1).
fn ordered_tags(file: &lofty::file::TaggedFile) -> Vec<&Tag> {
    let primary = file.primary_tag();
    primary
        .into_iter()
        .chain(file.tags().iter().filter(|t| Some(t.tag_type()) != primary.map(|p| p.tag_type())))
        .collect()
}

fn first<T>(tags: &[&Tag], get: impl Fn(&Tag) -> Option<T>) -> Option<T> {
    tags.iter().find_map(|tag| get(tag))
}

fn text(value: Option<std::borrow::Cow<'_, str>>) -> Option<String> {
    value.map(|v| v.trim().to_string()).filter(|v| !v.is_empty())
}

fn year_of(tag: &Tag) -> Option<i64> {
    tag.date().map(|d| d.year as i64).filter(|y| *y > 0).or_else(|| {
        let raw = tag.get_string(ItemKey::Year)?;
        raw.get(..4)?.parse().ok()
    })
}

fn lyrics_of(tag: &Tag) -> Option<String> {
    [ItemKey::Lyrics, ItemKey::UnsyncLyrics]
        .into_iter()
        .find_map(|key| tag.get_string(key).map(str::to_string).filter(|s| !s.trim().is_empty()))
}

/// Guesses an image MIME type from its magic bytes.
fn sniff_mime(data: &[u8]) -> &'static str {
    match data {
        [0x89, b'P', b'N', b'G', ..] => "image/png",
        [b'G', b'I', b'F', ..] => "image/gif",
        [b'R', b'I', b'F', b'F', _, _, _, _, b'W', b'E', b'B', b'P', ..] => "image/webp",
        _ => "image/jpeg",
    }
}

impl TagReader for LoftyTagReader {
    fn read(&self, path: &Path) -> Result<TrackMeta> {
        let file = lofty::read_from_path(path)?;
        let props = file.properties();
        let tags = ordered_tags(&file);
        Ok(TrackMeta {
            title: first(&tags, |t| text(t.title())),
            artist: first(&tags, |t| text(t.artist())),
            album: first(&tags, |t| text(t.album())),
            album_artist: first(&tags, |t| text(t.get_string(ItemKey::AlbumArtist).map(Into::into))),
            track_number: first(&tags, |t| t.track()).map(i64::from),
            disc_number: first(&tags, |t| t.disk()).map(i64::from),
            year: first(&tags, year_of),
            genre: first(&tags, |t| text(t.genre())),
            duration_ms: props.duration().as_millis() as i64,
            bitrate_kbps: props.audio_bitrate().or(props.overall_bitrate()).filter(|b| *b > 0).map(i64::from),
            has_embedded_cover: tags.iter().any(|t| !t.pictures().is_empty()),
            has_embedded_lyrics: tags.iter().any(|t| lyrics_of(t).is_some()),
        })
    }

    fn embedded_cover(&self, path: &Path) -> Option<Cover> {
        let file = lofty::read_from_path(path).ok()?;
        let tags = ordered_tags(&file);
        let pictures: Vec<_> = tags.iter().flat_map(|t| t.pictures()).collect();
        let picture = pictures
            .iter()
            .find(|p| p.pic_type() == PictureType::CoverFront)
            .or_else(|| pictures.first())?;
        let data = picture.data().to_vec();
        let mime = picture
            .mime_type()
            .map(|m| m.as_str().to_string())
            .filter(|m| m.starts_with("image/"))
            .unwrap_or_else(|| sniff_mime(&data).to_string());
        Some(Cover { data, mime })
    }

    fn embedded_lyrics(&self, path: &Path) -> Option<String> {
        let file = lofty::read_from_path(path).ok()?;
        let tags = ordered_tags(&file);
        first(&tags, lyrics_of)
    }
}
