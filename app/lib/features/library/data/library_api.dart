import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../domain/entities.dart';
import 'library_mappers.dart';

/// Remote adapter for the library endpoints.
class LibraryApi {
  LibraryApi(this._api);
  final ApiClient _api;

  static const pageSize = 1000;

  Future<Page<Track>> tracks({
    String? query,
    String? artistId,
    String? albumId,
    int limit = pageSize,
    int offset = 0,
  }) async {
    final body = await _api.get('/tracks', query: {
      'q': query,
      'artist_id': artistId,
      'album_id': albumId,
      'limit': limit,
      'offset': offset,
    });
    return Page(listItems(body).map(trackFromJson).toList(),
        asInt(asJson(body)['total']));
  }

  Future<Track> track(String id) async =>
      trackFromJson(asJson(await _api.get('/tracks/$id')));

  Future<Page<Album>> albums({String? artistId, int limit = pageSize, int offset = 0}) async {
    final body = await _api.get('/albums',
        query: {'artist_id': artistId, 'limit': limit, 'offset': offset});
    return Page(listItems(body).map(albumFromJson).toList(),
        asInt(asJson(body)['total']));
  }

  Future<AlbumDetail> album(String id) async {
    final body = asJson(await _api.get('/albums/$id'));
    return AlbumDetail(
      albumFromJson(asJson(body['album'])),
      asJsonList(body['tracks']).map(trackFromJson).toList(),
    );
  }

  Future<Page<Artist>> artists({int limit = pageSize, int offset = 0}) async {
    final body =
        await _api.get('/artists', query: {'limit': limit, 'offset': offset});
    return Page(listItems(body).map(artistFromJson).toList(),
        asInt(asJson(body)['total']));
  }

  Future<LibraryChanges> changes({String? since}) async =>
      changesFromJson(asJson(await _api.get('/library/changes', query: {'since': since})));

  Future<void> scan() => _api.post('/library/scan');

  Future<List<double>> waveform(String trackId) async {
    final body = asJson(await _api.get('/tracks/$trackId/waveform'));
    final peaks = body['peaks'];
    return peaks is List ? peaks.map((e) => asDouble(e).clamp(0.0, 1.0)).toList() : const [];
  }
}
