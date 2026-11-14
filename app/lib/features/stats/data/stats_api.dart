import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../library/data/library_mappers.dart';
import '../domain/play_record.dart';
import '../domain/stats_summary.dart';

StatsSummary statsFromJson(Json j) => StatsSummary(
      range: asString(j['range']),
      totalPlays: asInt(j['total_plays']),
      totalListenMs: asInt(j['total_listen_ms']),
      uniqueTracks: asInt(j['unique_tracks']),
      topTracks: asJsonList(j['top_tracks'])
          .map((e) => TopTrack(trackFromJson(asJson(e['track'])), asInt(e['plays'])))
          .toList(),
      topArtists: asJsonList(j['top_artists'])
          .map((e) => TopArtist(
                artistId: asString(e['artist_id']),
                name: asString(e['name']),
                plays: asInt(e['plays']),
              ))
          .toList(),
      daily: asJsonList(j['daily'])
          .map((e) => DailyListening(asString(e['date']), asInt(e['listen_ms'])))
          .toList(),
    );

Json playToJson(PlayRecord p) => {
      'client_id': p.clientId,
      'track_id': p.trackId,
      'played_at': toRfc3339(p.playedAt),
      'listened_ms': p.listenedMs,
    };

PlayRecord playFromJson(Json j) => PlayRecord(
      clientId: asString(j['client_id']),
      trackId: asString(j['track_id']),
      playedAt: DateTime.tryParse(asString(j['played_at']))?.toUtc() ?? DateTime.now().toUtc(),
      listenedMs: asInt(j['listened_ms']),
    );

class StatsApi {
  StatsApi(this._api);
  final ApiClient _api;

  Future<StatsSummary> summary(StatsRange range) async =>
      statsFromJson(asJson(await _api.get('/stats/summary', query: {'range': range.apiValue})));

  /// Returns the number of plays accepted (duplicates are not counted).
  Future<int> submitPlays(List<PlayRecord> plays) async {
    final body = await _api.post('/plays', body: {'plays': plays.map(playToJson).toList()});
    return asInt(asJson(body)['accepted']);
  }
}
