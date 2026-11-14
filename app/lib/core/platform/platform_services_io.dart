import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/downloads/data/file_download_store.dart';
import '../../features/library/data/drift_library_cache.dart';
import '../../features/stats/data/drift_plays_outbox.dart';
import 'platform_services.dart';
import 'qodi_database.dart';

const bool supportsOffline = true;

Future<PlatformServices> createPlatformServices(SharedPreferences prefs) async {
  final db = QodiDatabase(driftDatabase(name: 'qodi_music'));
  return PlatformServices(
    cache: DriftLibraryCache(db),
    outbox: DriftPlaysOutbox(db),
    createDownloads: (api) => FileDownloadStore(
      () async => Directory(p.join((await getApplicationDocumentsDirectory()).path, 'qodi_downloads')),
      (url, path, onProgress) => api.download(url, path, onProgress: onProgress),
    ),
  );
}
