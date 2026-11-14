import 'dart:convert';

import '../../../core/api/json.dart';
import '../../../core/platform/qodi_database.dart';
import '../domain/play_record.dart';
import 'stats_api.dart';

/// Plays outbox persisted in the native drift database.
class DriftPlaysOutbox implements PlaysOutbox {
  DriftPlaysOutbox(this._db);
  final QodiDatabase _db;

  @override
  Future<void> add(PlayRecord play) => _db.customStatement(
      'INSERT OR REPLACE INTO plays (client_id, json) VALUES (?, ?)',
      [play.clientId, jsonEncode(playToJson(play))]);

  @override
  Future<List<PlayRecord>> pending() async {
    final rows = await _db.customSelect('SELECT json FROM plays').get();
    return rows.map((r) => playFromJson(asJson(jsonDecode(r.read<String>('json'))))).toList();
  }

  @override
  Future<void> remove(Iterable<String> clientIds) => _db.transaction(() async {
        for (final id in clientIds) {
          await _db.customStatement('DELETE FROM plays WHERE client_id = ?', [id]);
        }
      });
}
