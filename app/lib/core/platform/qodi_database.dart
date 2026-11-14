import 'package:drift/drift.dart';

/// Native offline database (drift, raw SQL — no code generation needed).
///
/// Tables:
/// - `tracks(id PK, json)`: library cache synced from `/library/changes`.
/// - `kv(key PK, value)`: small key/values (e.g. last `server_time`).
/// - `plays(client_id PK, json)`: plays waiting to be sent to `/plays`.
class QodiDatabase extends GeneratedDatabase {
  QodiDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await customStatement(
              'CREATE TABLE IF NOT EXISTS tracks (id TEXT PRIMARY KEY NOT NULL, json TEXT NOT NULL)');
          await customStatement(
              'CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)');
          await customStatement(
              'CREATE TABLE IF NOT EXISTS plays (client_id TEXT PRIMARY KEY NOT NULL, json TEXT NOT NULL)');
        },
      );
}
