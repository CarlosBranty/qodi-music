import '../../../core/api/api_error.dart';
import '../domain/entities.dart';
import '../domain/library_repository.dart';
import 'library_api.dart';

/// Library repository that talks to the server and falls back to the local
/// cache when the server is unreachable (offline browsing).
class CachedLibraryRepository implements LibraryRepository {
  CachedLibraryRepository(this._remote, this._cache);

  final LibraryApi _remote;
  final LibraryCacheStore _cache;

  Future<T> _withFallback<T>(Future<T> Function() remote, Future<T> Function(List<Track>) local) async {
    try {
      return await remote();
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      final cached = await _cache.allTracks();
      if (cached.isEmpty) rethrow;
      return local(cached);
    }
  }

  @override
  Future<List<Track>> tracks({String? query, String? artistId, String? albumId}) =>
      _withFallback(
        () async => (await _remote.tracks(query: query, artistId: artistId, albumId: albumId)).items,
        (all) async => filterTracks(all, query: query, artistId: artistId, albumId: albumId),
      );

  @override
  Future<List<Album>> albums({String? artistId}) => _withFallback(
        () async => (await _remote.albums(artistId: artistId)).items,
        (all) async => deriveAlbums(artistId == null ? all : all.where((t) => t.artistId == artistId).toList()),
      );

  @override
  Future<List<Artist>> artists() => _withFallback(
        () async => (await _remote.artists()).items,
        (all) async => deriveArtists(all),
      );

  @override
  Future<AlbumDetail> album(String id) => _withFallback(
        () => _remote.album(id),
        (all) async {
          final tracks = filterTracks(all, albumId: id);
          if (tracks.isEmpty) throw const ApiException('not_found', 'Album not cached', statusCode: 404);
          return AlbumDetail(deriveAlbums(tracks).first, tracks);
        },
      );
}

int _compareTracks(Track a, Track b) {
  int c = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
  if (c != 0) return c;
  c = a.album.toLowerCase().compareTo(b.album.toLowerCase());
  if (c != 0) return c;
  c = (a.discNumber ?? 0).compareTo(b.discNumber ?? 0);
  if (c != 0) return c;
  c = (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
  if (c != 0) return c;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

List<Track> filterTracks(List<Track> all, {String? query, String? artistId, String? albumId}) {
  final q = query?.trim().toLowerCase() ?? '';
  final out = all.where((t) {
    if (artistId != null && t.artistId != artistId) return false;
    if (albumId != null && t.albumId != albumId) return false;
    if (q.isEmpty) return true;
    return t.title.toLowerCase().contains(q) ||
        t.artist.toLowerCase().contains(q) ||
        t.album.toLowerCase().contains(q);
  }).toList()
    ..sort(_compareTracks);
  return out;
}

List<Album> deriveAlbums(List<Track> tracks) {
  final groups = <String, List<Track>>{};
  for (final t in tracks) {
    groups.putIfAbsent(t.albumId, () => []).add(t);
  }
  final albums = groups.values.map((ts) {
    final first = ts.first;
    final cover = ts.where((t) => t.hasCover).firstOrNull;
    return Album(
      id: first.albumId,
      title: first.album,
      artist: first.albumArtist,
      artistId: first.artistId,
      year: first.year,
      trackCount: ts.length,
      durationMs: ts.fold(0, (s, t) => s + t.durationMs),
      coverTrackId: cover?.id,
    );
  }).toList()
    ..sort((a, b) {
      final c = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
      if (c != 0) return c;
      final y = (a.year ?? 0).compareTo(b.year ?? 0);
      return y != 0 ? y : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  return albums;
}

List<Artist> deriveArtists(List<Track> tracks) {
  final byArtist = <String, List<Track>>{};
  for (final t in tracks) {
    byArtist.putIfAbsent(t.artistId, () => []).add(t);
  }
  return byArtist.values
      .map((ts) => Artist(
            id: ts.first.artistId,
            name: ts.first.artist,
            albumCount: ts.map((t) => t.albumId).toSet().length,
            trackCount: ts.length,
          ))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
