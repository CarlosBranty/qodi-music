import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../domain/device_library.dart';
import '../domain/device_metadata.dart';
import '../domain/device_music_source.dart';
import '../domain/device_track.dart';

/// Tag reader used by the scanner; replaceable in tests.
typedef TagReader = ({RawTags tags, List<int>? cover}) Function(String path);

/// [DeviceFileScanner] walking real folders with `dart:io`. The walk and the
/// tag reading run in a background isolate ([Isolate.run]) so large
/// libraries never block the UI.
class IoDeviceScanner implements DeviceFileScanner {
  IoDeviceScanner({required this.coversDir, this.readTags = readAudioTags, this.useIsolate = true});

  /// Where embedded covers are extracted (app cache dir).
  final String coversDir;
  final TagReader readTags;
  final bool useIsolate;

  @override
  Future<DeviceScanResult> scan(List<String> folders, Map<String, FileStamp> known) {
    final args = _ScanArgs(folders, known, coversDir, readTags);
    return useIsolate ? Isolate.run(() => _scanSync(args)) : Future.value(_scanSync(args));
  }

  @override
  Future<void> deleteCovers(List<String> coverPaths) async {
    for (final cover in coverPaths) {
      if (!p.isWithin(coversDir, cover)) continue;
      try {
        await File(cover).delete();
      } catch (_) {}
    }
  }
}

class _ScanArgs {
  const _ScanArgs(this.folders, this.known, this.coversDir, this.readTags);
  final List<String> folders;
  final Map<String, FileStamp> known;
  final String coversDir;
  final TagReader readTags;
}

/// Lists every audio file under [roots] (recursively, skipping hidden
/// entries and symlink loops). Unreadable roots are added to [unreadable].
List<FileStamp> listAudioFiles(List<String> roots, List<String> unreadable) {
  final out = <FileStamp>[];
  final visited = <String>{};
  for (final rawRoot in roots) {
    final root = p.normalize(rawRoot);
    final rootDir = Directory(root);
    if (!rootDir.existsSync()) {
      unreadable.add(rawRoot);
      continue;
    }
    final stack = <Directory>[rootDir];
    while (stack.isNotEmpty) {
      final dir = stack.removeLast();
      try {
        if (!visited.add(dir.resolveSymbolicLinksSync())) continue;
      } catch (_) {
        continue;
      }
      List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false);
      } catch (_) {
        if (identical(dir, rootDir)) unreadable.add(rawRoot);
        continue;
      }
      for (final e in entries) {
        final name = p.basename(e.path);
        if (name.startsWith('.')) continue;
        if (e is Directory) {
          stack.add(e);
        } else if (e is File || e is Link) {
          final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
          if (!deviceAudioExtensions.contains(ext)) continue;
          try {
            final stat = File(e.path).statSync();
            if (stat.type != FileSystemEntityType.file) continue;
            out.add(FileStamp(e.path, stat.modified.millisecondsSinceEpoch, stat.size));
          } catch (_) {}
        }
      }
    }
  }
  return out;
}

DeviceScanResult _scanSync(_ScanArgs args) {
  final unreadable = <String>[];
  final found = listAudioFiles(args.folders, unreadable);
  final plan = planScan(found, args.known);
  final sidecarCovers = <String, String?>{};
  final read = <DeviceTrack>[];
  for (final stamp in plan.toRead) {
    read.add(_readTrack(stamp, args, sidecarCovers));
  }
  return DeviceScanResult(
    read: read,
    unchanged: plan.unchanged,
    removed: plan.removed,
    newPaths: plan.newPaths,
    unreadableFolders: unreadable,
  );
}

DeviceTrack _readTrack(FileStamp stamp, _ScanArgs args, Map<String, String?> sidecarCovers) {
  var tags = RawTags.empty;
  List<int>? coverBytes;
  try {
    final r = args.readTags(stamp.path);
    tags = r.tags;
    coverBytes = r.cover;
  } catch (_) {
    // Unreadable tags: fall back to file name / folder.
  }
  String? coverPath;
  if (coverBytes != null && coverBytes.isNotEmpty) {
    // Named by content: tracks of one album share a single cached file.
    final extracted = p.join(args.coversDir, '${sha1.convert(coverBytes)}.cover');
    try {
      final f = File(extracted);
      if (!f.existsSync()) {
        Directory(args.coversDir).createSync(recursive: true);
        f.writeAsBytesSync(coverBytes, flush: true);
      }
      coverPath = extracted;
    } catch (_) {}
  }
  final dir = p.dirname(stamp.path);
  coverPath ??= sidecarCovers.putIfAbsent(dir, () => findSidecarCover(dir));
  return buildDeviceTrack(
    path: stamp.path,
    mtimeMs: stamp.mtimeMs,
    sizeBytes: stamp.sizeBytes,
    tags: tags,
    coverPath: coverPath,
    lyricsPath: findSidecarLyrics(stamp.path),
  );
}

const _sidecarCoverNames = ['cover', 'folder', 'front', 'albumart', 'album'];
const _imageExtensions = ['.jpg', '.jpeg', '.png', '.webp'];

/// `cover.jpg`, `folder.png`, ... in [dir] (case-insensitive), or null.
String? findSidecarCover(String dir) {
  try {
    final byName = <String, String>{};
    for (final e in Directory(dir).listSync(followLinks: false)) {
      if (e is! File) continue;
      final name = p.basename(e.path).toLowerCase();
      if (_imageExtensions.contains(p.extension(name))) {
        byName[p.basenameWithoutExtension(name)] ??= e.path;
      }
    }
    for (final n in _sidecarCoverNames) {
      final hit = byName[n];
      if (hit != null) return hit;
    }
  } catch (_) {}
  return null;
}

/// The `<name>.lrc` file next to [audioPath], or null.
String? findSidecarLyrics(String audioPath) {
  for (final ext in const ['.lrc', '.LRC']) {
    final candidate = p.setExtension(audioPath, ext);
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

/// Reads tags and the front cover with the pure-Dart `audio_metadata_reader`.
({RawTags tags, List<int>? cover}) readAudioTags(String path) {
  final m = readMetadata(File(path), getImage: true);
  final bitrate = m.bitrate;
  final pictures = m.pictures;
  final front = pictures.where((pic) => pic.pictureType == PictureType.coverFront).firstOrNull ??
      pictures.firstOrNull;
  return (
    tags: RawTags(
      title: m.title,
      artist: m.artist,
      album: m.album,
      albumArtist: m.albumArtist,
      trackNumber: m.trackNumber,
      discNumber: m.discNumber,
      year: m.year?.year,
      genre: m.genres.firstOrNull,
      durationMs: m.duration?.inMilliseconds,
      bitrateKbps: bitrate == null ? null : (bitrate >= 10000 ? bitrate ~/ 1000 : bitrate),
      sampleRateHz: m.sampleRate,
    ),
    cover: front?.bytes,
  );
}
