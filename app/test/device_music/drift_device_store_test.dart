import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qodi_music/core/platform/qodi_database.dart';
import 'package:qodi_music/features/device_music/data/drift_device_store.dart';
import 'package:qodi_music/features/device_music/domain/device_metadata.dart';

void main() {
  late QodiDatabase db;
  late DriftDeviceStore store;
  var ids = 0;

  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() {
    db = QodiDatabase(NativeDatabase.memory());
    store = DriftDeviceStore(db, clock: () => DateTime.utc(2026, 11, 13), newId: () => 'pl${ids++}');
  });

  tearDown(() => db.close());

  test('local favorites are added and removed', () async {
    expect(await store.favoriteIds(), isEmpty);
    await store.setFavorite('device:a', true);
    await store.setFavorite('device:b', true);
    await store.setFavorite('device:a', false);
    expect(await store.favoriteIds(), {'device:b'});
  });

  test('local playlists: create, rename, ordered tracks, delete', () async {
    final p1 = await store.createPlaylist('Road');
    final p2 = await store.createPlaylist('Gym');
    await store.renamePlaylist(p1.id, 'Road trip');
    await store.setPlaylistTracks(p1.id, ['device:c', 'device:a', 'device:b']);
    await store.setPlaylistTracks(p1.id, ['device:b', 'device:c']);
    var lists = await store.playlists();
    expect(lists.map((l) => l.name), ['Road trip', 'Gym']);
    expect(lists.first.trackIds, ['device:b', 'device:c']);
    expect(lists.last.trackIds, isEmpty);

    await store.deletePlaylist(p2.id);
    lists = await store.playlists();
    expect(lists.map((l) => l.id), [p1.id]);
  });

  test('scan cache upserts by path and deletes removed paths', () async {
    final a = buildDeviceTrack(path: '/m/a.mp3', mtimeMs: 1, sizeBytes: 1);
    final b = buildDeviceTrack(path: '/m/b.mp3', mtimeMs: 1, sizeBytes: 1);
    await store.applyScan(upserts: [a, b], removedPaths: const []);
    final a2 = buildDeviceTrack(path: '/m/a.mp3', mtimeMs: 2, sizeBytes: 5, tags: const RawTags(title: 'New'));
    await store.applyScan(upserts: [a2], removedPaths: ['/m/b.mp3']);
    final rows = await store.loadTracks();
    expect(rows.single.track.title, 'New');
    expect(rows.single.mtimeMs, 2);
  });

  test('upgrading a v1 database keeps existing data and adds the device tables', () async {
    final dir = await Directory.systemTemp.createTemp('qodi_db_test_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'v1.sqlite'));
    // Recreate a v1 database (as shipped before device music) right before
    // drift opens it, so drift runs the v1 -> v2 upgrade.
    final upgraded = QodiDatabase(NativeDatabase(file, setup: (raw) {
      raw.execute('CREATE TABLE tracks (id TEXT PRIMARY KEY NOT NULL, json TEXT NOT NULL)');
      raw.execute('CREATE TABLE kv (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)');
      raw.execute('CREATE TABLE plays (client_id TEXT PRIMARY KEY NOT NULL, json TEXT NOT NULL)');
      raw.execute("INSERT INTO tracks VALUES ('t1', '{}')");
      raw.execute("INSERT INTO plays VALUES ('c1', '{}')");
      raw.execute('PRAGMA user_version = 1');
    }));
    addTearDown(upgraded.close);
    final tracks = await upgraded.customSelect('SELECT id FROM tracks').get();
    final plays = await upgraded.customSelect('SELECT client_id FROM plays').get();
    expect(tracks.single.read<String>('id'), 't1');
    expect(plays.single.read<String>('client_id'), 'c1');
    final s = DriftDeviceStore(upgraded);
    await s.setFavorite('device:x', true);
    expect(await s.favoriteIds(), {'device:x'});
  });
}
