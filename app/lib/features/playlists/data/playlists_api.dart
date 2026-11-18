import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../library/data/library_mappers.dart';
import '../../library/domain/entities.dart';
import '../domain/playlist.dart';

Playlist playlistFromJson(Json j) => Playlist(
      id: asString(j['id']),
      name: asString(j['name']),
      trackCount: asInt(j['track_count']),
      durationMs: asInt(j['duration_ms']),
      coverTrackId: asStringOrNull(j['cover_track_id']),
      createdAt: asString(j['created_at']),
      updatedAt: asString(j['updated_at']),
    );

Json playlistToJson(Playlist p) => {
      'id': p.id,
      'name': p.name,
      'track_count': p.trackCount,
      'duration_ms': p.durationMs,
      'cover_track_id': p.coverTrackId,
      'created_at': p.createdAt,
      'updated_at': p.updatedAt,
    };

class PlaylistsApi implements PlaylistRepository {
  PlaylistsApi(this._api);
  final ApiClient _api;

  @override
  Future<List<Playlist>> list() async =>
      listItems(await _api.get('/playlists')).map(playlistFromJson).toList();

  @override
  Future<Playlist> create(String name) async =>
      playlistFromJson(asJson(await _api.post('/playlists', body: {'name': name})));

  @override
  Future<PlaylistDetail> get(String id) async {
    final body = asJson(await _api.get('/playlists/$id'));
    return PlaylistDetail(
      playlistFromJson(asJson(body['playlist'])),
      asJsonList(body['tracks']).map(trackFromJson).toList(),
    );
  }

  @override
  Future<Playlist> rename(String id, String name) async =>
      playlistFromJson(asJson(await _api.patch('/playlists/$id', body: {'name': name})));

  @override
  Future<Playlist> setTracks(String id, List<Track> tracks) async => playlistFromJson(
      asJson(await _api.patch('/playlists/$id', body: {'track_ids': tracks.map((t) => t.id).toList()})));

  @override
  Future<void> delete(String id) => _api.delete('/playlists/$id');
}
