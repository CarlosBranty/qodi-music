import 'package:shared_preferences/shared_preferences.dart';

import '../../features/downloads/domain/download_store.dart';
import '../../features/library/domain/library_repository.dart';
import '../../features/stats/domain/play_record.dart';
import '../api/api_client.dart';
import 'platform_services_stub.dart'
    if (dart.library.io) 'platform_services_io.dart' as impl;

/// Platform-specific adapters. Native: drift cache, drift plays outbox and
/// file downloads. Web: in-memory cache, prefs outbox, no downloads.
class PlatformServices {
  const PlatformServices({
    required this.cache,
    required this.outbox,
    required this.createDownloads,
  });

  final LibraryCacheStore cache;
  final PlaysOutbox outbox;
  final DownloadStore? Function(ApiClient api) createDownloads;

  bool get supportsOffline => impl.supportsOffline;
}

Future<PlatformServices> createPlatformServices(SharedPreferences prefs) =>
    impl.createPlatformServices(prefs);
