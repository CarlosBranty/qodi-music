import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/download_store.dart';

typedef FileDownloader = Future<void> Function(
    String url, String savePath, void Function(int received, int total)? onProgress);

/// Stores downloaded tracks as `<documents>/qodi_downloads/<trackId>.<ext>`.
class FileDownloadStore implements DownloadStore {
  FileDownloadStore(this._dir, this._downloader);

  final Future<Directory> Function() _dir;
  final FileDownloader _downloader;

  Future<Directory> _root() async {
    final dir = await _dir();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<File>> _files() async {
    final root = await _root();
    return root
        .listSync()
        .whereType<File>()
        .where((f) => !f.path.endsWith('.part'))
        .toList();
  }

  String _idOf(File f) => p.basenameWithoutExtension(f.path);

  @override
  Future<String?> localPath(String trackId) async {
    for (final f in await _files()) {
      if (_idOf(f) == trackId) return f.path;
    }
    return null;
  }

  @override
  Future<Set<String>> downloadedIds() async => (await _files()).map(_idOf).toSet();

  @override
  Future<void> download(String trackId, Uri url, String extension,
      {void Function(double progress)? onProgress}) async {
    final root = await _root();
    final ext = extension.isEmpty ? 'bin' : extension;
    final target = p.join(root.path, '$trackId.$ext');
    final part = '$target.part';
    try {
      await _downloader(url.toString(), part, (r, t) {
        if (t > 0) onProgress?.call(r / t);
      });
      await File(part).rename(target);
    } catch (_) {
      final f = File(part);
      if (await f.exists()) await f.delete();
      rethrow;
    }
  }

  @override
  Future<void> delete(String trackId) async {
    for (final f in await _files()) {
      if (_idOf(f) == trackId) await f.delete();
    }
  }

  @override
  Future<int> totalBytes() async {
    var total = 0;
    for (final f in await _files()) {
      total += await f.length();
    }
    return total;
  }
}
