import '../../library/domain/entities.dart';

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.trackCount,
    required this.durationMs,
    required this.createdAt,
    required this.updatedAt,
    this.coverTrackId,
  });

  final String id;
  final String name;
  final int trackCount;
  final int durationMs;
  final String? coverTrackId;
  final String createdAt;
  final String updatedAt;
}

class PlaylistDetail {
  const PlaylistDetail(this.playlist, this.tracks);
  final Playlist playlist;
  final List<Track> tracks;
}

/// Port for playlist management.
abstract interface class PlaylistRepository {
  Future<List<Playlist>> list();
  Future<Playlist> create(String name);
  Future<PlaylistDetail> get(String id);
  Future<Playlist> rename(String id, String name);
  Future<Playlist> setTracks(String id, List<String> trackIds);
  Future<void> delete(String id);
}
