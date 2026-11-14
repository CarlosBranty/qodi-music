import 'package:path/path.dart' as p;

import '../../library/domain/audio_quality.dart';
import '../../library/domain/entities.dart';
import 'device_track.dart';

const unknownArtist = 'Unknown Artist';
const unknownAlbum = 'Unknown Album';

/// Tags read from an audio file. Every field is optional: unreadable or
/// untagged files fall back to the file name and folder, like the server.
class RawTags {
  const RawTags({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.genre,
    this.durationMs,
    this.bitrateKbps,
    this.sampleRateHz,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final String? genre;
  final int? durationMs;
  final int? bitrateKbps;
  final int? sampleRateHz;

  static const empty = RawTags();
}

String? _clean(String? v) {
  final t = v?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

int? _positive(int? v) => (v == null || v <= 0) ? null : v;

/// Builds a [DeviceTrack] applying the server's fallback rules:
/// title = file name without extension, artist = `Unknown Artist`,
/// album = parent folder name (or `Unknown Album`), album artist = artist.
DeviceTrack buildDeviceTrack({
  required String path,
  required int mtimeMs,
  required int sizeBytes,
  RawTags tags = RawTags.empty,
  String? coverPath,
  String? lyricsPath,
  p.Context? pathContext,
}) {
  final ctx = pathContext ?? p.context;
  final stem = ctx.basenameWithoutExtension(path);
  final dir = ctx.dirname(path);
  final folder = (dir == '.' || dir == ctx.rootPrefix(path)) ? '' : ctx.basename(dir);
  final title = _clean(tags.title) ?? (stem.isEmpty ? ctx.basename(path) : stem);
  final artist = _clean(tags.artist) ?? unknownArtist;
  final album = _clean(tags.album) ?? (_clean(folder) ?? unknownAlbum);
  final albumArtist = _clean(tags.albumArtist) ?? artist;
  final ext = ctx.extension(path).replaceFirst('.', '').toLowerCase();
  final track = Track(
    id: deviceTrackId(path),
    title: title,
    artist: artist,
    artistId: deviceArtistId(artist),
    album: album,
    albumId: deviceAlbumId(albumArtist, album),
    albumArtist: albumArtist,
    trackNumber: _positive(tags.trackNumber),
    discNumber: _positive(tags.discNumber),
    year: _positive(tags.year),
    genre: _clean(tags.genre),
    durationMs: tags.durationMs ?? 0,
    format: ext,
    bitrateKbps: _positive(tags.bitrateKbps),
    sampleRateHz: _positive(tags.sampleRateHz),
    // The tag reader exposes no bit depth/channels: lossless comes from the format.
    lossless: isLosslessFormat(ext),
    sizeBytes: sizeBytes,
    hasCover: coverPath != null,
    hasLyrics: lyricsPath != null,
    favorite: false,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(mtimeMs, isUtc: true).toIso8601String(),
  );
  return DeviceTrack(
    track: track,
    path: path,
    mtimeMs: mtimeMs,
    sizeBytes: sizeBytes,
    coverPath: coverPath,
    lyricsPath: lyricsPath,
  );
}
