import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/json.dart';
import '../../library/data/library_mappers.dart';
import '../../library/domain/entities.dart';
import '../domain/playlist.dart';
import 'playlists_api.dart';

/// Offline-first playlists, Spotify style.
///
/// * Reads go to [_remote] and are saved locally; when the server cannot be
///   reached the saved copy is returned. Loading the list also saves every
///   playlist's tracks, so all playlists open offline.
/// * Edits made without a connection are applied to the saved copy and queued
///   (the "outbox"). The queue is sent, in order, before the next server call.
///   Playlists created offline get a temporary `local-…` id that is mapped to
///   the server id once they are created there.
class CachedPlaylistRepository implements PlaylistRepository {
  CachedPlaylistRepository(
    this._remote,
    this._prefs, {
    required String? Function() userId,
    String Function()? newLocalId,
  }) : _userId = userId,
       _newLocalId = newLocalId ?? (() => 'local-${DateTime.now().microsecondsSinceEpoch}');

  final PlaylistRepository _remote;
  final SharedPreferences _prefs;
  final String? Function() _userId;
  final String Function() _newLocalId;

  /// One outbox flush per user at a time, shared by every instance.
  static final _flushes = <String, Future<void>>{};

  Future<void> _prefetching = Future.value();

  /// Completes when the new or changed playlists found by the last [list]
  /// are saved.
  @visibleForTesting
  Future<void> get prefetching => _prefetching;

  /// Number of offline edits waiting to be sent to the server.
  int get pendingChanges => _outbox.length;

  String get _scope => 'playlist_cache.${_userId() ?? ''}';
  String get _listKey => '$_scope.list';
  String get _outboxKey => '$_scope.outbox';
  String get _aliasesKey => '$_scope.aliases';
  String _detailKey(String id) => '$_scope.detail.$id';

  // ---------------------------------------------------------------- reads

  @override
  Future<List<Playlist>> list() async {
    try {
      await _flush();
      final list = await _remote.list();
      await _saveList(list);
      _prefetching = _prefetch(list);
      return list;
    } on ApiException catch (e) {
      final cached = _cachedList;
      if (!e.isNetwork || cached == null) rethrow;
      return cached;
    }
  }

  @override
  Future<PlaylistDetail> get(String id) async {
    try {
      await _flush();
      final detail = await _remote.get(_resolve(id));
      await _saveDetail(detail);
      return detail;
    } on ApiException catch (e) {
      final cached = _cachedDetail(_resolve(id));
      if (!e.isNetwork || cached == null) rethrow;
      return cached;
    }
  }

  Future<void> _prefetch(List<Playlist> list) async {
    for (final p in list) {
      // Unchanged since it was saved: nothing to download.
      if (_cachedDetail(p.id)?.playlist.updatedAt == p.updatedAt) continue;
      try {
        await _saveDetail(await _remote.get(p.id));
      } catch (_) {
        // Best effort: the playlist is saved the next time it loads.
      }
    }
  }

  // ---------------------------------------------------------------- edits

  @override
  Future<Playlist> create(String name) => _edit(
    online: () => _remote.create(name),
    offline: () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final p = Playlist(id: _newLocalId(), name: name, trackCount: 0, durationMs: 0, createdAt: now, updatedAt: now);
      await _saveList([p, ...?_cachedList]);
      await _saveDetail(PlaylistDetail(p, const []));
      await _enqueue({'op': 'create', 'id': p.id, 'name': name});
      return p;
    },
  );

  @override
  Future<Playlist> rename(String id, String name) => _edit(
    online: () => _remote.rename(_resolve(id), name),
    offline: () async {
      final real = _resolve(id);
      final p = await _updateLocal(real, (p, tracks) => (_copy(p, name: name), tracks));
      await _enqueue({'op': 'rename', 'id': real, 'name': name});
      return p;
    },
  );

  @override
  Future<Playlist> setTracks(String id, List<Track> tracks) => _edit(
    online: () => _remote.setTracks(_resolve(id), tracks),
    offline: () async {
      final real = _resolve(id);
      final p = await _updateLocal(real, (p, _) => (_withTracks(p, tracks), tracks));
      await _enqueue({'op': 'set_tracks', 'id': real, 'tracks': tracks.map(trackToJson).toList()});
      return p;
    },
  );

  @override
  Future<void> delete(String id) => _edit(
    online: () async {
      final real = _resolve(id);
      await _remote.delete(real);
      await _forget(real);
    },
    offline: () async {
      final real = _resolve(id);
      await _forget(real);
      final ops = _outbox;
      final createdOffline = ops.any((o) => o['op'] == 'create' && o['id'] == real);
      // Earlier edits of a deleted playlist are pointless; one created
      // offline never needs to reach the server at all.
      await _saveOutbox(ops.where((o) => o['id'] != real).toList());
      if (!createdOffline) await _enqueue({'op': 'delete', 'id': real});
    },
  );

  Future<T> _edit<T>({required Future<T> Function() online, required Future<T> Function() offline}) async {
    try {
      await _flush();
      return await online();
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      return offline();
    }
  }

  /// Applies [change] to the saved list entry and detail of [id].
  Future<Playlist> _updateLocal(String id, (Playlist, List<Track>) Function(Playlist, List<Track>) change) async {
    final list = _cachedList ?? const [];
    final detail = _cachedDetail(id);
    final current = detail?.playlist ?? list.where((p) => p.id == id).firstOrNull;
    if (current == null) throw _offlineUnavailable;
    final (p, tracks) = change(current, detail?.tracks ?? const []);
    await _saveList([for (final e in list) e.id == id ? p : e]);
    await _saveDetail(PlaylistDetail(p, tracks));
    return p;
  }

  Future<void> _forget(String id) async {
    final list = _cachedList;
    if (list != null) await _saveList(list.where((p) => p.id != id).toList());
    await _prefs.remove(_detailKey(id));
  }

  // ---------------------------------------------------------------- sync

  Future<void> _flush() {
    final scope = _scope;
    return _flushes[scope] ??= _sendOutbox().whenComplete(() {
      _flushes.remove(scope);
    });
  }

  /// Sends queued edits in order. A network error stops (and is rethrown so the
  /// caller falls back to the cache); an edit the server rejects (e.g. the
  /// playlist was deleted on another device) is dropped.
  Future<void> _sendOutbox() async {
    while (true) {
      final ops = _outbox;
      if (ops.isEmpty) return;
      final op = ops.first;
      final id = asString(op['id']);
      try {
        switch (op['op']) {
          case 'create':
            final created = await _remote.create(asString(op['name']));
            await _adoptServerId(id, created.id);
          case 'rename':
            await _remote.rename(id, asString(op['name']));
          case 'set_tracks':
            await _remote.setTracks(id, asJsonList(op['tracks']).map(trackFromJson).toList());
          case 'delete':
            await _remote.delete(id);
        }
      } on ApiException catch (e) {
        if (e.isNetwork) rethrow;
      }
      // Re-read: [_adoptServerId] rewrites the queue.
      await _saveOutbox(_outbox.skip(1).toList());
    }
  }

  Future<void> _adoptServerId(String localId, String serverId) async {
    final aliases = _aliases..[localId] = serverId;
    await _prefs.setString(_aliasesKey, jsonEncode(aliases));
    await _saveOutbox([
      for (final o in _outbox) o['id'] == localId ? {...o, 'id': serverId} : o,
    ]);
    final detail = _cachedDetail(localId);
    if (detail != null) {
      await _prefs.remove(_detailKey(localId));
      await _saveDetail(PlaylistDetail(_copy(detail.playlist, id: serverId), detail.tracks));
    }
    final list = _cachedList;
    if (list != null) {
      await _saveList([for (final p in list) p.id == localId ? _copy(p, id: serverId) : p]);
    }
  }

  String _resolve(String id) => _aliases[id] ?? id;

  Future<void> _enqueue(Json op) async {
    final kind = op['op'];
    final coalesce = kind == 'rename' || kind == 'set_tracks';
    await _saveOutbox([
      // A newer rename / track list replaces a queued one for the same playlist.
      for (final o in _outbox)
        if (!(coalesce && o['op'] == kind && o['id'] == op['id'])) o,
      op,
    ]);
  }

  // ---------------------------------------------------------------- storage

  List<Json> get _outbox => _readJson(_outboxKey, asJsonList) ?? [];
  Future<void> _saveOutbox(List<Json> ops) =>
      ops.isEmpty ? _prefs.remove(_outboxKey) : _prefs.setString(_outboxKey, jsonEncode(ops));

  Map<String, String> get _aliases =>
      _readJson(_aliasesKey, (raw) => asJson(raw).map((k, v) => MapEntry(k, asString(v)))) ?? {};

  List<Playlist>? get _cachedList => _readJson(_listKey, (raw) => asJsonList(raw).map(playlistFromJson).toList());

  Future<void> _saveList(List<Playlist> list) =>
      _prefs.setString(_listKey, jsonEncode(list.map(playlistToJson).toList()));

  PlaylistDetail? _cachedDetail(String id) => _readJson(_detailKey(id), (raw) {
    final j = asJson(raw);
    return PlaylistDetail(playlistFromJson(asJson(j['playlist'])), asJsonList(j['tracks']).map(trackFromJson).toList());
  });

  Future<void> _saveDetail(PlaylistDetail d) => _prefs.setString(
    _detailKey(d.playlist.id),
    jsonEncode({'playlist': playlistToJson(d.playlist), 'tracks': d.tracks.map(trackToJson).toList()}),
  );

  T? _readJson<T>(String key, T Function(Object? raw) decode) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return decode(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static const _offlineUnavailable = ApiException('network', 'This playlist is not available offline yet');

  static Playlist _copy(Playlist p, {String? id, String? name}) => Playlist(
    id: id ?? p.id,
    name: name ?? p.name,
    trackCount: p.trackCount,
    durationMs: p.durationMs,
    coverTrackId: p.coverTrackId,
    createdAt: p.createdAt,
    updatedAt: DateTime.now().toUtc().toIso8601String(),
  );

  static Playlist _withTracks(Playlist p, List<Track> tracks) => Playlist(
    id: p.id,
    name: p.name,
    trackCount: tracks.length,
    durationMs: tracks.fold(0, (sum, t) => sum + t.durationMs),
    coverTrackId: tracks.where((t) => t.hasCover).firstOrNull?.id,
    createdAt: p.createdAt,
    updatedAt: DateTime.now().toUtc().toIso8601String(),
  );
}
