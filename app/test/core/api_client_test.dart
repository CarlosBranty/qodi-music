import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/core/api/api_client.dart';
import 'package:qodi_music/core/api/api_error.dart';
import 'package:qodi_music/core/api/media_urls.dart';
import 'package:qodi_music/core/config/settings_store.dart';
import 'package:qodi_music/features/auth/data/auth_api.dart';
import 'package:qodi_music/features/library/data/cached_library_repository.dart';
import 'package:qodi_music/features/library/data/library_api.dart';
import 'package:qodi_music/features/library/data/memory_library_cache.dart';
import 'package:qodi_music/features/lyrics/data/lyrics_api.dart';
import 'package:qodi_music/features/playlists/data/playlists_api.dart';
import 'package:qodi_music/features/stats/data/stats_api.dart';
import 'package:qodi_music/features/stats/domain/play_record.dart';
import 'package:qodi_music/features/stats/domain/stats_summary.dart';

import '../support/fake_http.dart';
import '../support/fixtures.dart';

void main() {
  late FakeHttpAdapter http;
  late ApiClient api;
  late int unauthorizedCalls;

  ApiClient client(Map<String, FakeResponse> routes) {
    http = FakeHttpAdapter(routes);
    unauthorizedCalls = 0;
    return api = ApiClient(
      serverUrl: () => 'http://nas.local:4040/',
      token: () => 'tok123',
      onUnauthorized: () => unauthorizedCalls++,
      adapter: http,
    );
  }

  group('ApiClient transport', () {
    test('sends requests under /api/v1 with a Bearer token', () async {
      client({
        'GET /api/v1/me': const FakeResponse(200, {'id': 'u1', 'username': 'alice'})
      });
      await api.get('/me');
      final req = http.requests.single;
      expect(req.uri.toString(), 'http://nas.local:4040/api/v1/me');
      expect(req.headers['Authorization'], 'Bearer tok123');
    });

    test('401 unauthorized maps to UnauthorizedException and notifies', () async {
      client({
        'GET /api/v1/me': const FakeResponse(401, {
          'error': {'code': 'unauthorized', 'message': 'token expired'}
        })
      });
      await expectLater(api.get('/me'), throwsA(isA<UnauthorizedException>()));
      expect(unauthorizedCalls, 1);
    });

    test('error body maps to ApiException code/message/status', () async {
      client({
        'GET /api/v1/tracks/x': const FakeResponse(404, {
          'error': {'code': 'not_found', 'message': 'Track not found'}
        })
      });
      final error = await api.get('/tracks/x').then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, isA<ApiException>()
          .having((e) => e.code, 'code', 'not_found')
          .having((e) => e.message, 'message', 'Track not found')
          .having((e) => e.statusCode, 'status', 404));
      expect(unauthorizedCalls, 0);
    });

    test('connection failures map to a network error', () async {
      client({});
      http.offline = true;
      await expectLater(api.get('/me'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'network', true)));
    });

    test('media URLs carry the token as query parameter', () {
      client({});
      final urls = ApiMediaUrls(api);
      expect(urls.cover('abc'), 'http://nas.local:4040/api/v1/tracks/abc/cover?token=tok123');
      expect(urls.stream(track('abc'), StreamQuality.original).toString(),
          'http://nas.local:4040/api/v1/tracks/abc/stream?format=original&token=tok123');
      expect(urls.stream(track('abc'), StreamQuality.opus128).toString(),
          'http://nas.local:4040/api/v1/tracks/abc/stream?format=opus&bitrate=128&token=tok123');
    });

    test('Apple Lossless streams as lossless FLAC; other originals stay untouched', () {
      client({});
      final urls = ApiMediaUrls(api);
      final alac = track('abc', format: 'm4a', lossless: true);
      expect(urls.stream(alac, StreamQuality.original).toString(),
          'http://nas.local:4040/api/v1/tracks/abc/stream?format=flac&token=tok123');
      // AAC in .m4a and every other format keep the original bytes.
      for (final t in [track('abc', format: 'm4a'), track('abc', format: 'flac', lossless: true), track('abc')]) {
        expect(urls.stream(t, StreamQuality.original).toString(),
            'http://nas.local:4040/api/v1/tracks/abc/stream?format=original&token=tok123');
      }
      expect(urls.stream(alac, StreamQuality.opus128).toString(),
          'http://nas.local:4040/api/v1/tracks/abc/stream?format=opus&bitrate=128&token=tok123');
    });
  });

  group('JSON parsing', () {
    test('track list parses fields including nullable ones', () async {
      client({
        'GET /api/v1/tracks': FakeResponse(200, {
          'items': [trackJson(), trackJson(id: 'b', nulls: true)],
          'total': 2,
        })
      });
      final page = await LibraryApi(api).tracks(query: 'otoño');
      expect(http.requests.single.uri.queryParameters['q'], 'otoño');
      expect(page.total, 2);
      final full = page.items[0];
      expect(full.title, 'Semestre de Otoño');
      expect(full.artistId, 'a1');
      expect(full.trackNumber, 3);
      expect(full.discNumber, 1);
      expect(full.year, 2023);
      expect(full.genre, 'Pop');
      expect(full.bitrateKbps, 900);
      expect(full.duration, const Duration(milliseconds: 214000));
      expect(full.hasCover, isTrue);
      final sparse = page.items[1];
      expect(sparse.trackNumber, isNull);
      expect(sparse.discNumber, isNull);
      expect(sparse.year, isNull);
      expect(sparse.genre, isNull);
      expect(sparse.bitrateKbps, isNull);
    });

    test('album detail parses album with null year/cover and its tracks', () async {
      client({
        'GET /api/v1/albums/al1': FakeResponse(200, {
          'album': {
            'id': 'al1',
            'title': 'Querido',
            'artist': 'José Madero',
            'artist_id': 'a1',
            'year': null,
            'track_count': 12,
            'duration_ms': 2600000,
            'cover_track_id': null,
          },
          'tracks': [trackJson()],
        })
      });
      final d = await LibraryApi(api).album('al1');
      expect(d.album.title, 'Querido');
      expect(d.album.year, isNull);
      expect(d.album.coverTrackId, isNull);
      expect(d.album.trackCount, 12);
      expect(d.tracks.single.id, '9f2c1a7b3d4e5f60');
    });

    test('playlist list and patch body', () async {
      final playlist = {
        'id': 'p1',
        'name': 'Night drive',
        'track_count': 20,
        'duration_ms': 4300000,
        'cover_track_id': null,
        'created_at': '2026-11-13T20:15:00Z',
        'updated_at': '2026-11-13T21:15:00Z',
      };
      client({
        'GET /api/v1/playlists': FakeResponse(200, {'items': [playlist], 'total': 1}),
        'PATCH /api/v1/playlists/p1': FakeResponse(200, playlist),
      });
      final repo = PlaylistsApi(api);
      final list = await repo.list();
      expect(list.single.name, 'Night drive');
      expect(list.single.trackCount, 20);
      expect(list.single.coverTrackId, isNull);
      await repo.setTracks('p1', ['t2', 't1']);
      expect(http.bodies.last, {'track_ids': ['t2', 't1']});
    });

    test('stats summary parses totals, top lists and daily', () async {
      client({
        'GET /api/v1/stats/summary': FakeResponse(200, {
          'range': '7d',
          'total_plays': 120,
          'total_listen_ms': 25000000,
          'unique_tracks': 48,
          'top_tracks': [
            {'track': trackJson(), 'plays': 12}
          ],
          'top_artists': [
            {'artist_id': 'a1', 'name': 'José Madero', 'plays': 30}
          ],
          'daily': [
            {'date': '2026-11-13', 'listen_ms': 3600000}
          ],
        })
      });
      final s = await StatsApi(api).summary(StatsRange.week);
      expect(http.requests.single.uri.queryParameters['range'], '7d');
      expect(s.totalPlays, 120);
      expect(s.totalListenMs, 25000000);
      expect(s.uniqueTracks, 48);
      expect(s.topTracks.single.plays, 12);
      expect(s.topTracks.single.track.title, 'Semestre de Otoño');
      expect(s.topArtists.single.name, 'José Madero');
      expect(s.topArtistShare, closeTo(0.25, 1e-9));
      expect(s.daily.single.date, '2026-11-13');
      expect(s.daily.single.listenMs, 3600000);
    });

    test('plays are posted with RFC 3339 played_at', () async {
      client({
        'POST /api/v1/plays': const FakeResponse(200, {'accepted': 1})
      });
      final accepted = await StatsApi(api).submitPlays([
        PlayRecord(
          clientId: 'c-1',
          trackId: 't1',
          playedAt: DateTime.utc(2026, 11, 13, 20, 15, 0, 123),
          listenedMs: 31000,
        ),
      ]);
      expect(accepted, 1);
      expect(http.bodies.single, {
        'plays': [
          {'client_id': 'c-1', 'track_id': 't1', 'played_at': '2026-11-13T20:15:00Z', 'listened_ms': 31000}
        ]
      });
    });

    test('library changes parse tracks, removed ids and server_time', () async {
      client({
        'GET /api/v1/library/changes': FakeResponse(200, {
          'server_time': '2026-11-13T22:00:00Z',
          'tracks': [trackJson()],
          'removed_track_ids': ['gone1', 'gone2'],
        })
      });
      final c = await LibraryApi(api).changes(since: '2026-11-12T00:00:00Z');
      expect(http.requests.single.uri.queryParameters['since'], '2026-11-12T00:00:00Z');
      expect(c.serverTime, '2026-11-13T22:00:00Z');
      expect(c.tracks.single.id, '9f2c1a7b3d4e5f60');
      expect(c.removedTrackIds, ['gone1', 'gone2']);
    });

    test('lyrics parse synced lines; 404 means no lyrics', () async {
      client({
        'GET /api/v1/tracks/t1/lyrics': const FakeResponse(200, {
          'synced': true,
          'lines': [
            {'time_ms': 1000, 'text': 'Hello'},
            {'time_ms': null, 'text': 'world'},
          ],
        }),
      });
      final l = await LyricsApi(api).get('t1');
      expect(l!.synced, isTrue);
      expect(l.lines[0].time, const Duration(seconds: 1));
      expect(l.lines[1].time, isNull);
      expect(await LyricsApi(api).get('none'), isNull);
    });
  });

  group('AuthApi', () {
    test('login posts credentials and returns the session', () async {
      final adapter = FakeHttpAdapter({
        'POST /api/v1/auth/login': const FakeResponse(200, {
          'token': 'jwt',
          'user': {'id': 'u1', 'username': 'alice'}
        })
      });
      final s = await AuthApi(adapter: adapter).login('http://nas:4040/', 'alice', 'pw');
      expect(adapter.requests.single.uri.toString(), 'http://nas:4040/api/v1/auth/login');
      expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
      expect(adapter.bodies.single, {'username': 'alice', 'password': 'pw'});
      expect(s.serverUrl, 'http://nas:4040');
      expect(s.token, 'jwt');
      expect(s.user.username, 'alice');
    });

    test('401 invalid_credentials maps to InvalidCredentialsException', () async {
      final adapter = FakeHttpAdapter({
        'POST /api/v1/auth/login': const FakeResponse(401, {
          'error': {'code': 'invalid_credentials', 'message': 'Invalid username or password'}
        })
      });
      await expectLater(
          AuthApi(adapter: adapter).login('http://nas:4040', 'a', 'b'), throwsA(isA<InvalidCredentialsException>()));
    });
  });

  test('cached repository falls back to the cache when offline', () async {
    client({});
    http.offline = true;
    final cache = MemoryLibraryCache();
    await cache.upsertTracks([track('1', title: 'Alpha'), track('2', title: 'Beta')]);
    final repo = CachedLibraryRepository(LibraryApi(api), cache);
    final found = await repo.tracks(query: 'bet');
    expect(found.map((t) => t.id), ['2']);
    final albums = await repo.albums();
    expect(albums.single.trackCount, 2);
  });
}
