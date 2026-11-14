import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qodi_music/features/device_music/data/io_device_scanner.dart';
import 'package:qodi_music/features/device_music/data/scanning_device_music_source.dart';
import 'package:qodi_music/features/device_music/domain/device_metadata.dart';
import 'package:qodi_music/features/device_music/domain/device_music_source.dart';
import 'package:qodi_music/features/device_music/domain/device_track.dart';

class MemoryStore implements DeviceLibraryStore {
  final Map<String, DeviceTrack> rows = {};
  int applies = 0;

  @override
  Future<List<DeviceTrack>> loadTracks() async => rows.values.toList();

  @override
  Future<void> applyScan({required List<DeviceTrack> upserts, required List<String> removedPaths}) async {
    applies++;
    for (final r in removedPaths) {
      rows.remove(r);
    }
    for (final t in upserts) {
      rows[t.path] = t;
    }
  }
}

/// Top-level so it can be sent to the scan isolate. Files named `tagged*`
/// get tags and a cover; everything else throws like an unreadable file.
({RawTags tags, List<int>? cover}) fakeTags(String path) {
  if (!p.basename(path).startsWith('tagged')) throw const FormatException('no tags');
  return (tags: const RawTags(title: 'Tagged Song', artist: 'Band', album: 'Record'), cover: const [1, 2, 3]);
}

Future<String?> readText(String path) async {
  final f = File(path);
  return await f.exists() ? f.readAsString() : null;
}

void main() {
  late Directory tmp;
  late String music;
  late String covers;
  late MemoryStore store;
  late ScanningDeviceMusicSource source;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('qodi_scan_test_');
    music = p.join(tmp.path, 'Music');
    covers = p.join(tmp.path, 'cache', 'device_covers');
    await Directory(p.join(music, 'Album')).create(recursive: true);
    await Directory(p.join(music, '.hidden')).create(recursive: true);
    store = MemoryStore();
    source = ScanningDeviceMusicSource(
      store: store,
      scanner: IoDeviceScanner(coversDir: covers, readTags: fakeTags),
      readText: readText,
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> write(String rel, [List<int> bytes = const [0, 1, 2, 3]]) async {
    final f = File(p.join(music, rel));
    await f.parent.create(recursive: true);
    return f.writeAsBytes(bytes);
  }

  test('first scan finds audio files, reads tags/covers/lyrics, skips hidden and non-audio', () async {
    await write('tagged.mp3');
    await write('Album/02 Plain Song.flac');
    await write('.hidden/secret.mp3');
    await write('notes.txt');
    await File(p.join(music, 'Album', '02 Plain Song.lrc')).writeAsString('[00:01.00]Hi');

    final report = await source.rescan([music, p.join(tmp.path, 'missing')]);
    expect(report.added, 2);
    expect(report.updated, 0);
    expect(report.removed, 0);
    expect(report.unreadableFolders, [p.join(tmp.path, 'missing')]);

    final tracks = {for (final t in await source.tracks()) p.basename(t.path): t};
    expect(tracks.keys, unorderedEquals(['tagged.mp3', '02 Plain Song.flac']));

    final tagged = tracks['tagged.mp3']!;
    expect(tagged.track.title, 'Tagged Song');
    expect(tagged.track.hasCover, isTrue);
    expect(File(tagged.coverPath!).readAsBytesSync(), [1, 2, 3]);
    expect(source.coverPathOf(tagged.id), tagged.coverPath);

    final plain = tracks['02 Plain Song.flac']!;
    expect(plain.track.title, '02 Plain Song', reason: 'unreadable tags fall back to the file name');
    expect(plain.track.album, 'Album');
    expect(plain.track.artist, unknownArtist);
    expect(plain.track.hasLyrics, isTrue);
    expect(await source.readLyrics(plain.id), '[00:01.00]Hi');
    expect(source.pathOf(plain.id), plain.path);
    expect(store.rows.length, 2, reason: 'results are persisted');
  });

  test('rescan only re-reads new/changed files and drops removed ones', () async {
    final a = await write('tagged.mp3');
    final b = await write('Album/b.flac');
    final c = await write('Album/c.ogg');
    await source.rescan([music]);

    final again = await source.rescan([music]);
    expect((again.added, again.updated, again.removed, again.unchanged), (0, 0, 0, 3));

    await b.writeAsBytes(List.filled(50, 7)); // size changes
    await b.setLastModified(DateTime(2030));
    await c.delete();
    await write('Album/d.wav');
    final coverOfA = source.coverPathOf(deviceTrackId(a.path))!;
    await a.delete();

    final report = await source.rescan([music]);
    expect(report.added, 1);
    expect(report.updated, 1);
    expect(report.removed, 2);
    expect(report.unchanged, 0);
    final names = (await source.tracks()).map((t) => p.basename(t.path)).toSet();
    expect(names, {'b.flac', 'd.wav'});
    expect((await source.tracks()).firstWhere((t) => t.path == b.path).sizeBytes, 50);
    expect(File(coverOfA).existsSync(), isFalse, reason: 'extracted cover of a removed file is deleted');
    expect(source.pathOf(deviceTrackId(a.path)), isNull);
  });

  test('tracks with the same embedded cover share one cached file until the last is removed', () async {
    final one = await write('Album/tagged1.mp3');
    final two = await write('Album/tagged2.mp3');
    await source.rescan([music]);
    final cover = source.coverPathOf(deviceTrackId(one.path))!;
    expect(source.coverPathOf(deviceTrackId(two.path)), cover);
    expect(Directory(covers).listSync(), hasLength(1));

    await one.delete();
    await source.rescan([music]);
    expect(File(cover).existsSync(), isTrue, reason: 'still used by tagged2');

    await two.delete();
    await source.rescan([music]);
    expect(File(cover).existsSync(), isFalse);
  });

  test('a fresh source reuses the persisted cache (no re-read)', () async {
    await write('Album/x.mp3');
    await source.rescan([music]);
    final reopened = ScanningDeviceMusicSource(
      store: store,
      scanner: IoDeviceScanner(coversDir: covers, readTags: fakeTags),
      readText: readText,
    );
    expect((await reopened.tracks()).single.track.title, 'x');
    final report = await reopened.rescan([music]);
    expect(report.unchanged, 1);
    expect(report.added, 0);
  });

  test('real tag reader falls back gracefully on a corrupt file', () async {
    await write('Album/broken.mp3', List.filled(64, 0));
    final real = ScanningDeviceMusicSource(
      store: MemoryStore(),
      scanner: IoDeviceScanner(coversDir: covers),
      readText: readText,
    );
    final report = await real.rescan([music]);
    expect(report.added, 1);
    expect((await real.tracks()).single.track.title, 'broken');
  });
}
