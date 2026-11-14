import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/json.dart';
import '../domain/play_record.dart';
import 'stats_api.dart';

/// Plays outbox stored in shared preferences (used on web).
class PrefsPlaysOutbox implements PlaysOutbox {
  PrefsPlaysOutbox(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'plays_outbox';

  List<PlayRecord> _read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      return asJsonList(jsonDecode(raw)).map(playFromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<PlayRecord> plays) =>
      _prefs.setString(_key, jsonEncode(plays.map(playToJson).toList()));

  @override
  Future<void> add(PlayRecord play) => _write([..._read(), play]);

  @override
  Future<List<PlayRecord>> pending() async => _read();

  @override
  Future<void> remove(Iterable<String> clientIds) {
    final ids = clientIds.toSet();
    return _write(_read().where((p) => !ids.contains(p.clientId)).toList());
  }
}
