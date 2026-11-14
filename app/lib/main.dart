import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/core_providers.dart';
import 'core/config/settings_store.dart';
import 'core/platform/platform_services.dart';
import 'features/device_music/domain/device_track.dart';
import 'features/player/data/qodi_audio_handler.dart';
import 'features/player/ui/player_providers.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // just_audio on Linux/Windows through media_kit (libmpv).
  JustAudioMediaKit.ensureInitialized(linux: true, windows: true);

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs);
  final platform = await createPlatformServices(prefs);
  final container = ProviderContainer(
    overrides: [
      settingsStoreProvider.overrideWithValue(settings),
      platformServicesProvider.overrideWithValue(platform),
    ],
    retry: (_, _) => null,
  );

  // Background playback + OS media controls.
  final port = container.read(playerPortProvider);
  final urls = container.read(mediaUrlsProvider);
  try {
    await AudioService.init(
      builder: () => QodiAudioHandler(port, (t) {
        if (isDeviceTrackId(t.id)) {
          final path = platform.device?.source.coverPathOf(t.id);
          return path == null ? null : Uri.file(path);
        }
        final cover = urls.cover(t.id);
        return cover == null ? null : Uri.parse(cover);
      }),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'dev.qodi.qodi_music.playback',
        // Shown in Android's notification settings; uses the language
        // preference (or device language) at start-up.
        androidNotificationChannelName: appStringsFor(settings.language).playbackChannelName,
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    debugPrint('AudioService unavailable: $e');
  }

  runApp(UncontrolledProviderScope(container: container, child: const QodiApp()));
}
