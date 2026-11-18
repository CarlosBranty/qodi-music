import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/core/api/api_error.dart';
import 'package:qodi_music/features/playlists/data/cached_playlist_repository.dart';
import 'package:qodi_music/features/playlists/domain/playlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fixtures.dart';

const _p1 = Playlist(
  id: 'p1',
  name: 'Night drive',
  trackCount: 2,
  durationMs: 1000,
  createdAt: '2026-11-13T20:15:00Z',
  updatedAt: '2026-11-13T21:15:00Z',
);

class _Remote implements PlaylistRepository {
  Object? failWith;
  List<Playlist> playlists = [_p1];
  PlaylistDetail detail = PlaylistDetail(_p1, [track('a'), track('b')]);
  final deleted = <String>[];

  Future<T> _run<T>(T value) async {
    if (failWith != null) throw failWith!;
    return value;
  }

  @override
  Future<List<Playlist>> list() => _run(playlists);
  @override
  Future<PlaylistDetail> get(String id) => _run(detail);
  @override
  Future<void> delete(String id) async {
    await _run(null);
    deleted.add(id);
  }

  @override
  Future<Playlist> create(String name) => _run(_p1);
  @override
  Future<Playlist> rename(String id, String name) => _run(_p1);
  @override
  Future<Playlist> setTracks(String id, List<String> trackIds) => _run(_p1);
}

void main() {
  late _Remote remote;
  late SharedPreferences prefs;
  CachedPlaylistRepository repo({String userId = 'u1'}) =>
      CachedPlaylistRepository(remote, prefs, userId: () => userId);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    remote = _Remote();
  });

  test('offline: playlists load from the last successful fetch', () async {
    expect((await repo().list()).single.name, 'Night drive');
    expect((await repo().get('p1')).tracks.map((t) => t.id), ['a', 'b']);

    remote.failWith = const ApiException('network', 'Cannot reach the server');
    final list = await repo().list();
    expect(list.single.id, 'p1');
    expect(list.single.trackCount, 2);
    final detail = await repo().get('p1');
    expect(detail.playlist.name, 'Night drive');
    expect(detail.tracks.map((t) => t.id), ['a', 'b']);
  });

  test('offline without a cache still reports the network error', () async {
    remote.failWith = const ApiException('network', 'Cannot reach the server');
    await expectLater(repo().list(), throwsA(isA<ApiException>()));
    await expectLater(repo().get('p1'), throwsA(isA<ApiException>()));
  });

  test('server errors are not hidden by the cache', () async {
    await repo().get('p1');
    remote.failWith = const ApiException('not_found', 'gone', statusCode: 404);
    await expectLater(repo().get('p1'), throwsA(isA<ApiException>()));
  });

  test('the cache is per user', () async {
    await repo().list();
    remote.failWith = const ApiException('network', 'offline');
    await expectLater(repo(userId: 'u2').list(), throwsA(isA<ApiException>()));
  });

  test('deleting a playlist drops its cached detail', () async {
    await repo().get('p1');
    await repo().delete('p1');
    expect(remote.deleted, ['p1']);
    remote.failWith = const ApiException('network', 'offline');
    await expectLater(repo().get('p1'), throwsA(isA<ApiException>()));
  });
}
