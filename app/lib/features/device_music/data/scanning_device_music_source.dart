import 'package:path/path.dart' as p;

import '../domain/device_music_source.dart';
import '../domain/device_track.dart';

/// Reads a text file; null when it does not exist or cannot be read.
typedef ReadTextFile = Future<String?> Function(String path);

/// [DeviceMusicSource] backed by a persistent [DeviceLibraryStore] (cache of
/// the last scan) and a [DeviceFileScanner] (incremental disk walk).
class ScanningDeviceMusicSource implements DeviceMusicSource {
  ScanningDeviceMusicSource({
    required DeviceLibraryStore store,
    required DeviceFileScanner scanner,
    required ReadTextFile readText,
  })  : _store = store,
        _scanner = scanner,
        _readText = readText;

  final DeviceLibraryStore _store;
  final DeviceFileScanner _scanner;
  final ReadTextFile _readText;
  Map<String, DeviceTrack>? _byPath;
  final Map<String, DeviceTrack> _byId = {};
  Future<DeviceScanReport>? _scanning;

  Future<Map<String, DeviceTrack>> _index() async {
    final cached = _byPath;
    if (cached != null) return cached;
    final loaded = await _store.loadTracks();
    _setIndex({for (final t in loaded) t.path: t});
    return _byPath!;
  }

  void _setIndex(Map<String, DeviceTrack> byPath) {
    _byPath = byPath;
    _byId
      ..clear()
      ..addEntries(byPath.values.map((t) => MapEntry(t.id, t)));
  }

  @override
  Future<List<DeviceTrack>> tracks() async => (await _index()).values.toList();

  @override
  Future<DeviceScanReport> rescan(List<String> folders) =>
      _scanning ??= _rescan(folders).whenComplete(() => _scanning = null);

  Future<DeviceScanReport> _rescan(List<String> folders) async {
    final index = await _index();
    final known = {
      for (final t in index.values) t.path: FileStamp(t.path, t.mtimeMs, t.sizeBytes),
    };
    final result = await _scanner.scan(folders, known);
    await _store.applyScan(upserts: result.read, removedPaths: result.removed);
    // Previous versions of removed or re-read tracks: their covers may be orphaned.
    final replaced = [
      for (final path in result.removed) ?index[path],
      for (final t in result.read) ?index[t.path],
    ];
    final next = Map.of(index);
    for (final path in result.removed) {
      next.remove(path);
    }
    for (final t in result.read) {
      next[t.path] = t;
    }
    _setIndex(next);
    final inUse = {for (final t in next.values) ?t.coverPath};
    final orphans = {for (final t in replaced) ?t.coverPath}.difference(inUse);
    if (orphans.isNotEmpty) await _scanner.deleteCovers(orphans.toList());
    final added = result.read.where((t) => result.newPaths.contains(t.path)).length;
    return DeviceScanReport(
      added: added,
      updated: result.read.length - added,
      removed: result.removed.length,
      unchanged: result.unchanged.length,
      unreadableFolders: result.unreadableFolders,
    );
  }

  @override
  String? pathOf(String trackId) => _byId[trackId]?.path;

  @override
  String? coverPathOf(String trackId) => _byId[trackId]?.coverPath;

  @override
  Future<String?> readLyrics(String trackId) async {
    await _index();
    final t = _byId[trackId];
    if (t == null) return null;
    // A `.lrc` added after the scan is picked up too.
    return _readText(t.lyricsPath ?? p.setExtension(t.path, '.lrc'));
  }
}
