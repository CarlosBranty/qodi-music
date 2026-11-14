import 'package:shared_preferences/shared_preferences.dart';

import '../../features/library/data/memory_library_cache.dart';
import '../../features/stats/data/prefs_plays_outbox.dart';
import 'platform_services.dart';

const bool supportsOffline = false;

Future<PlatformServices> createPlatformServices(SharedPreferences prefs) async =>
    PlatformServices(
      cache: MemoryLibraryCache(),
      outbox: PrefsPlaysOutbox(prefs),
      createDownloads: (_) => null,
    );
