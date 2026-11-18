import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/core/api/api_error.dart';
import 'package:qodi_music/features/library/domain/entities.dart';
import 'package:qodi_music/features/playlists/data/cached_playlist_repository.dart';
import 'package:qodi_music/features/playlists/domain/playlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fixtures.dart';

Playlist _playlist(String id, {String name = 'Night drive', int count = 2}) => Playlist(
  id: id,
  name: name,
  trackCount: count,
  durationMs: 1000,
  createdAt: '2026-11-13T20:15:00Z',
  updatedAt: '2026-11-13T21:15:00Z',
);

const _offline = ApiException('network', 'Cannot reach the server');

/// In-memory server that records every call.
class _Remote implements PlaylistRepository {
  Object? failWith;
  final playlists = <String, Playlist>{'p1': _playlist('p1'), 'p2': _playlist('p2', name: 'Gym')};
  final tracks = <String, List<Track>>{
    'p1': [track('a'), track('b')],
    'p2': [track('c')],
  };
  final calls = <String>[];
  var _next = 0;

  Future<T> _run<T>(String call, T Function() body) async {
    await Future<void>.delayed(Duration.zero);
    if (failWith != null) throw failWith!;
    calls.add(call);
    return body();
  }

  @override
  Future<List<Playlist>> list() => _run('list', () => playlists.values.toList());
  @override
  Future<PlaylistDetail> get(String id) => _run('get $id', () {
    final p = playlists[id];
    if (p == null) throw const ApiException('not_found', 'gone', statusCode: 404);
    return PlaylistDetail(p, tracks[id] ?? const []);
  });
  @override
  Future<Playlist> create(String name) => _run('create $name', () {
    final p = _playlist('srv${_next++}', name: name, count: 0);
    playlists[p.id] = p;
    return p;
  });
  @override
  Future<Playlist> rename(String id, String name) => _run('rename $id $name', () {
    if (!playlists.containsKey(id)) throw const ApiException('not_found', 'gone', statusCode: 404);
    return playlists[id] = _playlist(id, name: name);
  });
  @override
  Future<Playlist> setTracks(String id, List<Track> list) =>
      _run('setTracks $id ${list.map((t) => t.id).join(',')}', () {
        tracks[id] = list;
        return playlists[id]!;
      });
  @override
  Future<void> delete(String id) => _run('delete $id', () => playlists.remove(id));
}

void main() {
  late _Remote remote;
  late SharedPreferences prefs;
  var localIds = 0;
  CachedPlaylistRepository repo({String userId = 'u1'}) =>
      CachedPlaylistRepository(remote, prefs, userId: () => userId, newLocalId: () => 'local-${localIds++}');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    localIds = 0;
    prefs = await SharedPreferences.getInstance();
    remote = _Remote();
  });

  group('offline reads', () {
    test('playlists load from the last successful fetch', () async {
      expect((await repo().list()).map((p) => p.name), ['Night drive', 'Gym']);
      expect((await repo().get('p1')).tracks.map((t) => t.id), ['a', 'b']);

      remote.failWith = _offline;
      final list = await repo().list();
      expect(list.first.id, 'p1');
      expect(list.first.trackCount, 2);
      final detail = await repo().get('p1');
      expect(detail.playlist.name, 'Night drive');
      expect(detail.tracks.map((t) => t.id), ['a', 'b']);
    });

    test('loading the list saves every playlist, even ones never opened', () async {
      final r = repo();
      await r.list();
      await r.prefetching;
      remote.failWith = _offline;
      expect((await repo().get('p2')).tracks.map((t) => t.id), ['c']);
    });

    test('offline without a cache still reports the network error', () async {
      remote.failWith = _offline;
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
      remote.failWith = _offline;
      await expectLater(repo(userId: 'u2').list(), throwsA(isA<ApiException>()));
    });
  });

  group('online edits (previous behavior)', () {
    test('go straight to the server', () async {
      final r = repo();
      await r.rename('p1', 'Late drive');
      await r.setTracks('p1', [track('b'), track('a')]);
      final created = await r.create('New');
      await r.delete('p2');
      expect(remote.calls, ['rename p1 Late drive', 'setTracks p1 b,a', 'create New', 'delete p2']);
      expect(created.id, 'srv0');
    });

    test('deleting a playlist drops its cached detail', () async {
      await repo().get('p1');
      await repo().delete('p1');
      remote.failWith = _offline;
      await expectLater(repo().get('p1'), throwsA(isA<ApiException>()));
    });
  });

  group('offline edits', () {
    setUp(() async {
      final r = repo();
      await r.list();
      await r.prefetching;
      remote.calls.clear();
      remote.failWith = _offline;
    });

    test('rename and reorder show up offline and sync later, latest state only', () async {
      final r = repo();
      await r.rename('p1', 'Draft');
      await r.rename('p1', 'Late drive');
      await r.setTracks('p1', [track('b')]);
      await r.setTracks('p1', [track('b'), track('a'), track('z')]);

      final list = await r.list();
      expect(list.first.name, 'Late drive');
      expect(list.first.trackCount, 3);
      expect((await r.get('p1')).tracks.map((t) => t.id), ['b', 'a', 'z']);
      expect(remote.calls, isEmpty);

      remote.failWith = null;
      await repo().list();
      expect(remote.calls.take(2), ['rename p1 Late drive', 'setTracks p1 b,a,z']);
      expect(remote.calls, contains('list'));
      expect(repo().pendingChanges, 0);
    });

    test('a playlist created offline can be filled and is created on the server later', () async {
      final r = repo();
      final created = await r.create('Road trip');
      expect(created.id, 'local-0');
      await r.setTracks(created.id, [track('a')]);
      expect((await r.list()).map((p) => p.name), contains('Road trip'));
      expect((await r.get(created.id)).tracks.map((t) => t.id), ['a']);

      remote.failWith = null;
      await repo().list();
      expect(remote.calls.take(2), ['create Road trip', 'setTracks srv0 a']);
      // The screen opened with the local id keeps working.
      expect((await repo().get('local-0')).playlist.id, 'srv0');
    });

    test('deleting offline hides the playlist and deletes it on the server later', () async {
      final r = repo();
      await r.delete('p2');
      expect((await r.list()).map((p) => p.id), ['p1']);

      remote.failWith = null;
      await repo().list();
      expect(remote.calls.first, 'delete p2');
    });

    test('a playlist created and deleted offline never reaches the server', () async {
      final r = repo();
      final created = await r.create('Oops');
      await r.rename(created.id, 'Oops 2');
      await r.delete(created.id);
      expect(r.pendingChanges, 0);

      remote.failWith = null;
      final online = repo();
      await online.list();
      await online.prefetching;
      // Nothing changed on the server, so nothing is downloaded again.
      expect(remote.calls, ['list']);
    });

    test('a change the server rejects is dropped and the rest still sync', () async {
      final r = repo();
      await r.rename('p2', 'Gone');
      await r.rename('p1', 'Kept');
      remote.playlists.remove('p2'); // deleted from another device

      remote.failWith = null;
      await repo().list();
      // p2 is attempted (404) and dropped; p1 is still sent.
      expect(remote.calls.take(2), ['rename p2 Gone', 'rename p1 Kept']);
      expect(repo().pendingChanges, 0);
    });

    test('two loads at once sync each change only once', () async {
      await repo().create('Once');
      remote.failWith = null;
      final r = repo();
      await Future.wait([r.list(), r.get('local-0'), r.list()]);
      expect(remote.calls.where((c) => c == 'create Once'), hasLength(1));
    });
  });
}
