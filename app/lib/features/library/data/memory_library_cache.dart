import '../domain/entities.dart';
import '../domain/library_repository.dart';

/// In-memory library cache used on web (no offline persistence there).
class MemoryLibraryCache implements LibraryCacheStore {
  final Map<String, Track> _tracks = {};
  String? _serverTime;

  @override
  Future<List<Track>> allTracks() async => _tracks.values.toList();

  @override
  Future<void> upsertTracks(List<Track> tracks) async {
    for (final t in tracks) {
      _tracks[t.id] = t;
    }
  }

  @override
  Future<void> removeTracks(List<String> ids) async => ids.forEach(_tracks.remove);

  @override
  Future<String?> serverTime() async => _serverTime;

  @override
  Future<void> setServerTime(String value) async => _serverTime = value;

  @override
  Future<void> clear() async {
    _tracks.clear();
    _serverTime = null;
  }
}
