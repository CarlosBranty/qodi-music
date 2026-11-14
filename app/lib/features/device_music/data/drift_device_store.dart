import 'package:uuid/uuid.dart';

import '../../../core/platform/qodi_database.dart';
import '../domain/device_music_source.dart';
import '../domain/device_track.dart';
import 'device_track_codec.dart';

/// Device scan cache plus local favorites/playlists in the native drift
/// database.
class DriftDeviceStore implements DeviceLibraryStore, DeviceCollections {
  DriftDeviceStore(this._db, {DateTime Function()? clock, String Function()? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? (() => const Uuid().v4());

  final QodiDatabase _db;
  final DateTime Function() _clock;
  final String Function() _newId;

  String _now() => _clock().toUtc().toIso8601String();

  // ---- scan cache ----

  @override
  Future<List<DeviceTrack>> loadTracks() async {
    final rows = await _db.customSelect('SELECT json FROM device_tracks').get();
    final out = <DeviceTrack>[];
    for (final r in rows) {
      try {
        out.add(decodeDeviceTrack(r.read<String>('json')));
      } catch (_) {
        // Skip corrupt rows; the next scan re-reads the file.
      }
    }
    return out;
  }

  @override
  Future<void> applyScan({required List<DeviceTrack> upserts, required List<String> removedPaths}) =>
      _db.transaction(() async {
        for (final path in removedPaths) {
          await _db.customStatement('DELETE FROM device_tracks WHERE path = ?', [path]);
        }
        for (final t in upserts) {
          await _db.customStatement(
            'INSERT OR REPLACE INTO device_tracks (path, id, mtime_ms, size_bytes, json) VALUES (?, ?, ?, ?, ?)',
            [t.path, t.id, t.mtimeMs, t.sizeBytes, encodeDeviceTrack(t)],
          );
        }
      });

  // ---- favorites ----

  @override
  Future<Set<String>> favoriteIds() async {
    final rows = await _db.customSelect('SELECT track_id FROM device_favorites ORDER BY added_at DESC').get();
    return {for (final r in rows) r.read<String>('track_id')};
  }

  @override
  Future<void> setFavorite(String trackId, bool favorite) => favorite
      ? _db.customStatement('INSERT OR REPLACE INTO device_favorites (track_id, added_at) VALUES (?, ?)',
          [trackId, _clock().millisecondsSinceEpoch])
      : _db.customStatement('DELETE FROM device_favorites WHERE track_id = ?', [trackId]);

  // ---- playlists ----

  @override
  Future<List<DevicePlaylist>> playlists() async {
    final rows = await _db
        .customSelect('SELECT id, name, created_at, updated_at FROM device_playlists ORDER BY created_at')
        .get();
    final tracks = await _db
        .customSelect('SELECT playlist_id, track_id FROM device_playlist_tracks ORDER BY playlist_id, position')
        .get();
    final byPlaylist = <String, List<String>>{};
    for (final r in tracks) {
      byPlaylist.putIfAbsent(r.read<String>('playlist_id'), () => []).add(r.read<String>('track_id'));
    }
    return [
      for (final r in rows)
        DevicePlaylist(
          id: r.read<String>('id'),
          name: r.read<String>('name'),
          trackIds: byPlaylist[r.read<String>('id')] ?? const [],
          createdAt: r.read<String>('created_at'),
          updatedAt: r.read<String>('updated_at'),
        ),
    ];
  }

  @override
  Future<DevicePlaylist> createPlaylist(String name) async {
    final now = _now();
    final p = DevicePlaylist(id: _newId(), name: name, trackIds: const [], createdAt: now, updatedAt: now);
    await _db.customStatement(
        'INSERT INTO device_playlists (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)',
        [p.id, p.name, p.createdAt, p.updatedAt]);
    return p;
  }

  @override
  Future<void> renamePlaylist(String id, String name) => _db.customStatement(
      'UPDATE device_playlists SET name = ?, updated_at = ? WHERE id = ?', [name, _now(), id]);

  @override
  Future<void> deletePlaylist(String id) => _db.transaction(() async {
        await _db.customStatement('DELETE FROM device_playlist_tracks WHERE playlist_id = ?', [id]);
        await _db.customStatement('DELETE FROM device_playlists WHERE id = ?', [id]);
      });

  @override
  Future<void> setPlaylistTracks(String id, List<String> trackIds) => _db.transaction(() async {
        await _db.customStatement('DELETE FROM device_playlist_tracks WHERE playlist_id = ?', [id]);
        for (var i = 0; i < trackIds.length; i++) {
          await _db.customStatement(
              'INSERT INTO device_playlist_tracks (playlist_id, position, track_id) VALUES (?, ?, ?)',
              [id, i, trackIds[i]]);
        }
        await _db.customStatement('UPDATE device_playlists SET updated_at = ? WHERE id = ?', [_now(), id]);
      });
}
