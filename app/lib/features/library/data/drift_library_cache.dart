import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/api/json.dart';
import '../../../core/platform/qodi_database.dart';
import '../domain/entities.dart';
import '../domain/library_repository.dart';
import 'library_mappers.dart';

/// Persistent library cache (native only).
class DriftLibraryCache implements LibraryCacheStore {
  DriftLibraryCache(this._db);
  final QodiDatabase _db;

  @override
  Future<List<Track>> allTracks() async {
    final rows = await _db.customSelect('SELECT json FROM tracks').get();
    return rows.map((r) => trackFromJson(asJson(jsonDecode(r.read<String>('json'))))).toList();
  }

  @override
  Future<void> upsertTracks(List<Track> tracks) => _db.transaction(() async {
        for (final t in tracks) {
          await _db.customStatement(
              'INSERT OR REPLACE INTO tracks (id, json) VALUES (?, ?)', [t.id, jsonEncode(trackToJson(t))]);
        }
      });

  @override
  Future<void> removeTracks(List<String> ids) => _db.transaction(() async {
        for (final id in ids) {
          await _db.customStatement('DELETE FROM tracks WHERE id = ?', [id]);
        }
      });

  @override
  Future<String?> serverTime() async {
    final row = await _db
        .customSelect('SELECT value FROM kv WHERE key = ?', variables: [Variable.withString('server_time')])
        .getSingleOrNull();
    return row?.read<String>('value');
  }

  @override
  Future<void> setServerTime(String value) => _db.customStatement(
      'INSERT OR REPLACE INTO kv (key, value) VALUES (?, ?)', ['server_time', value]);

  @override
  Future<void> clear() async {
    await _db.customStatement('DELETE FROM tracks');
    await _db.customStatement('DELETE FROM kv');
  }
}
