import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/json.dart';
import '../../library/data/library_mappers.dart';
import '../domain/playlist.dart';
import 'playlists_api.dart';

/// Keeps the last successfully fetched playlists so they can be browsed (and
/// their downloaded tracks played) without a connection.
///
/// Reads go to [_remote] first; only a network failure falls back to the
/// cache. Mutations always need the server.
class CachedPlaylistRepository implements PlaylistRepository {
  CachedPlaylistRepository(this._remote, this._prefs, {required String? Function() userId}) : _userId = userId;

  final PlaylistRepository _remote;
  final SharedPreferences _prefs;
  final String? Function() _userId;

  String get _scope => 'playlist_cache.${_userId() ?? ''}';
  String get _listKey => '$_scope.list';
  String _detailKey(String id) => '$_scope.detail.$id';

  @override
  Future<List<Playlist>> list() => _readThrough(
    fetch: _remote.list,
    key: _listKey,
    encode: (list) => list.map(playlistToJson).toList(),
    decode: (raw) => asJsonList(raw).map(playlistFromJson).toList(),
  );

  @override
  Future<PlaylistDetail> get(String id) => _readThrough(
    fetch: () => _remote.get(id),
    key: _detailKey(id),
    encode: (d) => {'playlist': playlistToJson(d.playlist), 'tracks': d.tracks.map(trackToJson).toList()},
    decode: (raw) {
      final j = asJson(raw);
      return PlaylistDetail(
        playlistFromJson(asJson(j['playlist'])),
        asJsonList(j['tracks']).map(trackFromJson).toList(),
      );
    },
  );

  @override
  Future<void> delete(String id) async {
    await _remote.delete(id);
    await _prefs.remove(_detailKey(id));
  }

  @override
  Future<Playlist> create(String name) => _remote.create(name);

  @override
  Future<Playlist> rename(String id, String name) => _remote.rename(id, name);

  @override
  Future<Playlist> setTracks(String id, List<String> trackIds) => _remote.setTracks(id, trackIds);

  Future<T> _readThrough<T>({
    required Future<T> Function() fetch,
    required String key,
    required Object Function(T value) encode,
    required T Function(Object? raw) decode,
  }) async {
    try {
      final value = await fetch();
      await _prefs.setString(key, jsonEncode(encode(value)));
      return value;
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      final raw = _prefs.getString(key);
      if (raw == null) rethrow;
      return decode(jsonDecode(raw));
    }
  }
}
