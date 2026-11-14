import '../../downloads/domain/download_store.dart';
import '../domain/library_repository.dart';
import 'library_api.dart';

/// Keeps the local cache in sync with `GET /library/changes?since=`.
/// Removed tracks are dropped from the cache and their downloads deleted.
class LibrarySyncService {
  LibrarySyncService(this._api, this._cache, this._downloads);

  final LibraryApi _api;
  final LibraryCacheStore _cache;
  final DownloadStore? _downloads;

  /// Returns the number of changed + removed tracks.
  Future<int> sync() async {
    final since = await _cache.serverTime();
    final changes = await _api.changes(since: since);
    await _cache.upsertTracks(changes.tracks);
    if (changes.removedTrackIds.isNotEmpty) {
      await _cache.removeTracks(changes.removedTrackIds);
      for (final id in changes.removedTrackIds) {
        await _downloads?.delete(id);
      }
    }
    if (changes.serverTime.isNotEmpty) {
      await _cache.setServerTime(changes.serverTime);
    }
    return changes.tracks.length + changes.removedTrackIds.length;
  }
}
