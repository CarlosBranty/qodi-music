import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/device_music/data/drift_device_store.dart';
import '../../features/device_music/data/io_device_platform.dart';
import '../../features/device_music/data/io_device_scanner.dart';
import '../../features/device_music/data/scanning_device_music_source.dart';
import '../../features/device_music/domain/device_music_source.dart';
import '../../features/downloads/data/file_download_store.dart';
import '../../features/library/data/drift_library_cache.dart';
import '../../features/stats/data/drift_plays_outbox.dart';
import 'platform_services.dart';
import 'qodi_database.dart';

const bool supportsOffline = true;

Future<PlatformServices> createPlatformServices(SharedPreferences prefs) async {
  final db = QodiDatabase(driftDatabase(name: 'qodi_music'));
  final deviceStore = DriftDeviceStore(db);
  final cacheDir = (await getApplicationCacheDirectory()).path;
  final documentsDir = (await getApplicationDocumentsDirectory()).path;
  return PlatformServices(
    cache: DriftLibraryCache(db),
    outbox: DriftPlaysOutbox(db),
    createDownloads: (api) => FileDownloadStore(
      () async => Directory(p.join((await getApplicationDocumentsDirectory()).path, 'qodi_downloads')),
      (url, path, onProgress) => api.download(url, path, onProgress: onProgress),
    ),
    device: DeviceMusicServices(
      source: ScanningDeviceMusicSource(
        store: deviceStore,
        scanner: IoDeviceScanner(coversDir: p.join(cacheDir, 'device_covers')),
        readText: readTextFile,
      ),
      collections: deviceStore,
      platform: IoDeviceMusicPlatform(importsDir: p.join(documentsDir, 'Music')),
    ),
  );
}

Future<String?> readTextFile(String path) async {
  try {
    final f = File(path);
    if (!await f.exists()) return null;
    return await f.readAsString();
  } catch (_) {
    return null;
  }
}
