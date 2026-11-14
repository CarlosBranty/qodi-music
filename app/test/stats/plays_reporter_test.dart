import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/core/api/api_client.dart';
import 'package:qodi_music/features/stats/data/plays_reporter.dart';
import 'package:qodi_music/features/stats/data/stats_api.dart';
import 'package:qodi_music/features/stats/domain/play_record.dart';

import '../support/fake_http.dart';

class ListOutbox implements PlaysOutbox {
  final List<PlayRecord> items = [];
  @override
  Future<void> add(PlayRecord play) async => items.add(play);
  @override
  Future<List<PlayRecord>> pending() async => List.of(items);
  @override
  Future<void> remove(Iterable<String> clientIds) async => items.removeWhere((p) => clientIds.contains(p.clientId));
}

PlayRecord play(String trackId) =>
    PlayRecord(clientId: 'c-$trackId', trackId: trackId, playedAt: DateTime.utc(2026), listenedMs: 40000);

void main() {
  late FakeHttpAdapter http;
  late ListOutbox outbox;

  PlaysReporter reporter({bool connected = true}) {
    http = FakeHttpAdapter({'POST /api/v1/plays': const FakeResponse(200, {'accepted': 1})});
    outbox = ListOutbox();
    final api = ApiClient(serverUrl: () => 'http://nas', token: () => 'tok', adapter: http);
    return PlaysReporter(StatsApi(api), outbox, canFlush: () => connected);
  }

  test('server plays are still queued and sent', () async {
    await reporter().record(play('9f2c1a7b'));
    expect(http.requests.map((r) => r.uri.path), ['/api/v1/plays']);
    expect(outbox.items, isEmpty);
  });

  test('device plays are never queued nor sent', () async {
    await reporter().record(play('device:abc'));
    expect(http.requests, isEmpty);
    expect(outbox.items, isEmpty);
  });

  test('without a server session plays stay queued and nothing is sent', () async {
    final r = reporter(connected: false);
    await r.record(play('9f2c1a7b'));
    await r.flush();
    expect(http.requests, isEmpty);
    expect(outbox.items.single.trackId, '9f2c1a7b');
  });
}
