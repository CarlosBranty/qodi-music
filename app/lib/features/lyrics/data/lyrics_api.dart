import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/json.dart';
import '../domain/lyrics.dart';

Lyrics lyricsFromJson(Json j) => Lyrics(
      synced: asBool(j['synced']),
      lines: asJsonList(j['lines']).map((l) {
        final ms = asIntOrNull(l['time_ms']);
        return LyricLine(ms == null ? null : Duration(milliseconds: ms), asString(l['text']));
      }).toList(),
    );

class LyricsApi {
  LyricsApi(this._api);
  final ApiClient _api;

  /// Returns null when the track has no lyrics (404).
  Future<Lyrics?> get(String trackId) async {
    try {
      return lyricsFromJson(asJson(await _api.get('/tracks/$trackId/lyrics')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }
}
