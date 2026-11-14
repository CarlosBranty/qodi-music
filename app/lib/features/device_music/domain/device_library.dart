import '../../library/domain/entities.dart';
import 'device_track.dart';

/// What an incremental rescan has to do, given the files found on disk and
/// the stamps cached from the previous scan.
class ScanPlan {
  const ScanPlan({required this.toRead, required this.unchanged, required this.removed, required this.newPaths});

  /// New or changed files whose tags must be (re)read.
  final List<FileStamp> toRead;

  /// Paths whose size and mtime did not change.
  final List<String> unchanged;

  /// Cached paths that are no longer on disk.
  final List<String> removed;

  /// Subset of [toRead] that was not cached before.
  final Set<String> newPaths;
}

ScanPlan planScan(Iterable<FileStamp> found, Map<String, FileStamp> known) {
  final toRead = <FileStamp>[];
  final unchanged = <String>[];
  final newPaths = <String>{};
  final seen = <String>{};
  for (final f in found) {
    if (!seen.add(f.path)) continue;
    final previous = known[f.path];
    if (previous == null) {
      toRead.add(f);
      newPaths.add(f.path);
    } else if (previous.sameAs(f)) {
      unchanged.add(f.path);
    } else {
      toRead.add(f);
    }
  }
  final removed = known.keys.where((k) => !seen.contains(k)).toList();
  return ScanPlan(toRead: toRead, unchanged: unchanged, removed: removed, newPaths: newPaths);
}

int _compareTracks(Track a, Track b) {
  final album = a.album.toLowerCase().compareTo(b.album.toLowerCase());
  if (album != 0) return album;
  final disc = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
  if (disc != 0) return disc;
  final n = (a.trackNumber ?? 1 << 20).compareTo(b.trackNumber ?? 1 << 20);
  if (n != 0) return n;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

/// Songs sorted by title.
List<Track> sortByTitle(Iterable<Track> tracks) =>
    tracks.toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

/// Albums of the device tracks, sorted by title.
List<Album> deviceAlbums(Iterable<Track> tracks) {
  final groups = <String, List<Track>>{};
  for (final t in tracks) {
    groups.putIfAbsent(t.albumId, () => []).add(t);
  }
  final albums = groups.entries.map((e) {
    final list = e.value..sort(_compareTracks);
    final first = list.first;
    final cover = list.where((t) => t.hasCover).firstOrNull;
    return Album(
      id: e.key,
      title: first.album,
      artist: first.albumArtist,
      artistId: deviceArtistId(first.albumArtist),
      year: list.map((t) => t.year).whereType<int>().firstOrNull,
      trackCount: list.length,
      durationMs: list.fold(0, (s, t) => s + t.durationMs),
      coverTrackId: cover?.id,
    );
  }).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return albums;
}

/// Artists (track artists) of the device tracks, sorted by name.
List<Artist> deviceArtists(Iterable<Track> tracks) {
  final groups = <String, List<Track>>{};
  for (final t in tracks) {
    groups.putIfAbsent(t.artistId, () => []).add(t);
  }
  return groups.entries
      .map((e) => Artist(
            id: e.key,
            name: e.value.first.artist,
            albumCount: e.value.map((t) => t.albumId).toSet().length,
            trackCount: e.value.length,
          ))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Tracks of an album in disc/track order.
List<Track> albumTracks(Iterable<Track> tracks, String albumId) =>
    tracks.where((t) => t.albumId == albumId).toList()..sort(_compareTracks);

/// Tracks of an artist grouped by album.
List<Track> artistTracks(Iterable<Track> tracks, String artistId) =>
    tracks.where((t) => t.artistId == artistId || deviceArtistId(t.albumArtist) == artistId).toList()
      ..sort(_compareTracks);

/// Case-insensitive search on title, artist and album (every word must match).
List<Track> searchTracks(Iterable<Track> tracks, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return tracks.toList();
  return tracks.where((t) {
    final text = '${t.title}\n${t.artist}\n${t.album}'.toLowerCase();
    return words.every(text.contains);
  }).toList();
}
