import 'package:drift/drift.dart';

/// Native offline database (drift, raw SQL — no code generation needed).
///
/// Tables:
/// - `tracks(id PK, json)`: library cache synced from `/library/changes`.
/// - `kv(key PK, value)`: small key/values (e.g. last `server_time`).
/// - `plays(client_id PK, json)`: plays waiting to be sent to `/plays`.
/// - v2 `device_tracks(path PK, ...)`: music found on the device (scan cache).
/// - v2 `device_favorites`, `device_playlists`, `device_playlist_tracks`:
///   local favorites/playlists of device tracks.
class QodiDatabase extends GeneratedDatabase {
  QodiDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await customStatement(
              'CREATE TABLE IF NOT EXISTS tracks (id TEXT PRIMARY KEY NOT NULL, json TEXT NOT NULL)');
          await customStatement(
              'CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)');
          await customStatement(
              'CREATE TABLE IF NOT EXISTS plays (client_id TEXT PRIMARY KEY NOT NULL, json TEXT NOT NULL)');
          await _createDeviceTables();
        },
        onUpgrade: (m, from, to) async {
          // v1 -> v2: add the device music tables; existing data is untouched.
          if (from < 2) await _createDeviceTables();
        },
      );

  Future<void> _createDeviceTables() async {
    await customStatement('CREATE TABLE IF NOT EXISTS device_tracks ('
        'path TEXT PRIMARY KEY NOT NULL, id TEXT NOT NULL, mtime_ms INTEGER NOT NULL, '
        'size_bytes INTEGER NOT NULL, json TEXT NOT NULL)');
    await customStatement('CREATE INDEX IF NOT EXISTS device_tracks_id ON device_tracks (id)');
    await customStatement('CREATE TABLE IF NOT EXISTS device_favorites ('
        'track_id TEXT PRIMARY KEY NOT NULL, added_at INTEGER NOT NULL)');
    await customStatement('CREATE TABLE IF NOT EXISTS device_playlists ('
        'id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
    await customStatement('CREATE TABLE IF NOT EXISTS device_playlist_tracks ('
        'playlist_id TEXT NOT NULL, position INTEGER NOT NULL, track_id TEXT NOT NULL, '
        'PRIMARY KEY (playlist_id, position))');
  }
}
