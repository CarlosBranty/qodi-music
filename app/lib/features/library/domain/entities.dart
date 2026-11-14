/// Core library entities. Pure Dart: no Flutter UI, no HTTP.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.artistId,
    required this.album,
    required this.albumId,
    required this.albumArtist,
    required this.durationMs,
    required this.format,
    required this.sizeBytes,
    required this.hasCover,
    required this.hasLyrics,
    required this.favorite,
    required this.updatedAt,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.genre,
    this.bitrateKbps,
    this.sampleRateHz,
    this.bitDepth,
    this.channels,
    this.lossless = false,
  });

  final String id;
  final String title;
  final String artist;
  final String artistId;
  final String album;
  final String albumId;
  final String albumArtist;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final String? genre;
  final int durationMs;
  final String format;
  final int? bitrateKbps;

  /// Audio properties (null when unknown, e.g. older servers; [bitDepth] is
  /// null for lossy codecs).
  final int? sampleRateHz;
  final int? bitDepth;
  final int? channels;
  final bool lossless;
  final int sizeBytes;
  final bool hasCover;
  final bool hasLyrics;
  final bool favorite;
  final String updatedAt;

  Duration get duration => Duration(milliseconds: durationMs);

  Track copyWith({bool? favorite}) => Track(
        id: id,
        title: title,
        artist: artist,
        artistId: artistId,
        album: album,
        albumId: albumId,
        albumArtist: albumArtist,
        trackNumber: trackNumber,
        discNumber: discNumber,
        year: year,
        genre: genre,
        durationMs: durationMs,
        format: format,
        bitrateKbps: bitrateKbps,
        sampleRateHz: sampleRateHz,
        bitDepth: bitDepth,
        channels: channels,
        lossless: lossless,
        sizeBytes: sizeBytes,
        hasCover: hasCover,
        hasLyrics: hasLyrics,
        favorite: favorite ?? this.favorite,
        updatedAt: updatedAt,
      );

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.artistId,
    required this.trackCount,
    required this.durationMs,
    this.year,
    this.coverTrackId,
  });

  final String id;
  final String title;
  final String artist;
  final String artistId;
  final int? year;
  final int trackCount;
  final int durationMs;
  final String? coverTrackId;
}

class Artist {
  const Artist({
    required this.id,
    required this.name,
    required this.albumCount,
    required this.trackCount,
  });

  final String id;
  final String name;
  final int albumCount;
  final int trackCount;
}

class AlbumDetail {
  const AlbumDetail(this.album, this.tracks);
  final Album album;
  final List<Track> tracks;
}

class Page<T> {
  const Page(this.items, this.total);
  final List<T> items;
  final int total;
}

/// Result of `GET /library/changes`.
class LibraryChanges {
  const LibraryChanges({
    required this.serverTime,
    required this.tracks,
    required this.removedTrackIds,
  });

  final String serverTime;
  final List<Track> tracks;
  final List<String> removedTrackIds;
}
