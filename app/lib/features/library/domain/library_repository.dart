import 'entities.dart';

/// Port for browsing the music library.
abstract interface class LibraryRepository {
  Future<List<Track>> tracks({String? query, String? artistId, String? albumId});
  Future<List<Album>> albums({String? artistId});
  Future<List<Artist>> artists();
  Future<AlbumDetail> album(String id);
}

/// Port for the local library cache (drift on native, memory on web).
abstract interface class LibraryCacheStore {
  Future<List<Track>> allTracks();
  Future<void> upsertTracks(List<Track> tracks);
  Future<void> removeTracks(List<String> ids);
  Future<String?> serverTime();
  Future<void> setServerTime(String value);
  Future<void> clear();
}
