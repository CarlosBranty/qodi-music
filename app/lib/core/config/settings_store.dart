import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/library/data/library_mappers.dart';
import '../../features/library/domain/entities.dart';
import '../api/json.dart';

enum StreamQuality {
  original('Original', 'Lossless / source file'),
  opus128('Opus 128 kbps', 'Saves data, transcoded on the server');

  const StreamQuality(this.label, this.description);
  final String label;
  final String description;
}

enum AppThemePreference { system, light, dark }

/// Persists session and preferences in shared preferences.
class SettingsStore {
  SettingsStore(this._prefs);
  final SharedPreferences _prefs;

  static const _kServer = 'server_url';
  static const _kToken = 'token';
  static const _kUserId = 'user_id';
  static const _kUsername = 'username';
  static const _kTheme = 'theme';
  static const _kQuality = 'quality';
  static const _kHistory = 'history';
  static const historyLimit = 30;

  SharedPreferences get prefs => _prefs;

  String? get serverUrl => _prefs.getString(_kServer);
  String? get token => _prefs.getString(_kToken);

  AuthSession? get session {
    final server = serverUrl, t = token, name = _prefs.getString(_kUsername);
    if (server == null || t == null || t.isEmpty || name == null) return null;
    return AuthSession(
      serverUrl: server,
      token: t,
      user: AuthUser(id: _prefs.getString(_kUserId) ?? '', username: name),
    );
  }

  Future<void> saveSession(AuthSession s) async {
    await _prefs.setString(_kServer, s.serverUrl);
    await _prefs.setString(_kToken, s.token);
    await _prefs.setString(_kUserId, s.user.id);
    await _prefs.setString(_kUsername, s.user.username);
  }

  /// Clears the token but keeps the server URL to prefill the login form.
  Future<void> clearSession() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kUsername);
  }

  AppThemePreference get theme => AppThemePreference.values
      .firstWhere((e) => e.name == _prefs.getString(_kTheme), orElse: () => AppThemePreference.system);
  Future<void> setTheme(AppThemePreference v) => _prefs.setString(_kTheme, v.name);

  StreamQuality get quality => StreamQuality.values
      .firstWhere((e) => e.name == _prefs.getString(_kQuality), orElse: () => StreamQuality.original);
  Future<void> setQuality(StreamQuality v) => _prefs.setString(_kQuality, v.name);

  /// Recently played tracks, most recent first.
  List<Track> get history {
    final raw = _prefs.getString(_kHistory);
    if (raw == null) return const [];
    try {
      return asJsonList(jsonDecode(raw)).map(trackFromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Track>> pushHistory(Track t) async {
    final list = [t, ...history.where((e) => e.id != t.id)].take(historyLimit).toList();
    await _prefs.setString(_kHistory, jsonEncode(list.map(trackToJson).toList()));
    return list;
  }
}
