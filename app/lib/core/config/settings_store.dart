import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/equalizer/domain/equalizer.dart';
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
  static const _kIsAdmin = 'is_admin';
  static const _kTheme = 'theme';
  static const _kQuality = 'quality';
  static const _kHistory = 'history';
  static const _kDeviceOnly = 'device_only';
  static const _kDeviceFolders = 'device_folders';
  static const _kEqualizer = 'equalizer';
  static const _kUpdateLastCheck = 'update_last_check';
  static const _kUpdateLastResult = 'update_last_result';
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
      user: AuthUser(
        id: _prefs.getString(_kUserId) ?? '',
        username: name,
        isAdmin: _prefs.getBool(_kIsAdmin) ?? false,
      ),
    );
  }

  Future<void> saveSession(AuthSession s) async {
    await _prefs.setString(_kServer, s.serverUrl);
    await _prefs.setString(_kToken, s.token);
    await _prefs.setString(_kUserId, s.user.id);
    await _prefs.setString(_kUsername, s.user.username);
    await _prefs.setBool(_kIsAdmin, s.user.isAdmin);
  }

  /// Clears the token but keeps the server URL to prefill the login form.
  Future<void> clearSession() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kUsername);
    await _prefs.remove(_kIsAdmin);
  }

  /// "Use without server": the app runs on device music only.
  bool get deviceOnly => _prefs.getBool(_kDeviceOnly) ?? false;
  Future<void> setDeviceOnly(bool v) => _prefs.setBool(_kDeviceOnly, v);

  /// Extra folders scanned for device music (besides the platform defaults).
  List<String> get deviceFolders => _prefs.getStringList(_kDeviceFolders) ?? const [];
  Future<void> setDeviceFolders(List<String> v) => _prefs.setStringList(_kDeviceFolders, v);

  AppThemePreference get theme => AppThemePreference.values
      .firstWhere((e) => e.name == _prefs.getString(_kTheme), orElse: () => AppThemePreference.system);
  Future<void> setTheme(AppThemePreference v) => _prefs.setString(_kTheme, v.name);

  StreamQuality get quality => StreamQuality.values
      .firstWhere((e) => e.name == _prefs.getString(_kQuality), orElse: () => StreamQuality.original);
  Future<void> setQuality(StreamQuality v) => _prefs.setString(_kQuality, v.name);

  /// Equalizer on/off, preset and custom gains (JSON).
  EqualizerSettings get equalizer {
    final raw = _prefs.getString(_kEqualizer);
    if (raw == null) return EqualizerSettings.defaults;
    try {
      return EqualizerSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return EqualizerSettings.defaults;
    }
  }

  Future<void> setEqualizer(EqualizerSettings v) => _prefs.setString(_kEqualizer, jsonEncode(v.toJson()));

  /// Last Android update check (time and a short result text).
  DateTime? get updateLastCheck {
    final ms = _prefs.getInt(_kUpdateLastCheck);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  String? get updateLastResult => _prefs.getString(_kUpdateLastResult);

  Future<void> setUpdateCheck(DateTime at, String result) async {
    await _prefs.setInt(_kUpdateLastCheck, at.millisecondsSinceEpoch);
    await _prefs.setString(_kUpdateLastResult, result);
  }

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
