import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/config/core_providers.dart';
import '../../downloads/ui/downloads_controller.dart';
import '../../equalizer/data/just_audio_equalizer.dart';
import '../../equalizer/ui/equalizer_controller.dart';
import '../../library/ui/library_providers.dart';
import '../../settings/ui/settings_controllers.dart';
import '../../stats/ui/stats_providers.dart';
import '../data/just_audio_player_service.dart';
import '../domain/player_port.dart';
import '../domain/track_source.dart';

/// The app-wide player. Tests override it with a fake [PlayerPort].
final playerPortProvider = Provider<PlayerPort>((ref) {
  final urls = ref.read(mediaUrlsProvider);
  final service = JustAudioPlayerService(
    resolveSource: (track) => resolveTrackSource(
      track,
      devicePath: (id) async {
        final source = ref.read(platformServicesProvider).device?.source;
        if (source == null) return null;
        await source.tracks(); // loads the index on a cold start
        return source.pathOf(id);
      },
      downloadPath: (id) async => ref.read(downloadStoreProvider)?.localPath(id),
      stream: (id) => urls.stream(id, ref.read(qualityProvider)),
    ),
    recorder: ref.read(playRecorderProvider),
    onPlay: (play) => ref.read(playsReporterProvider).record(play),
    onTrackStarted: (track) => ref.read(historyProvider.notifier).push(track),
    // The equalizer (Android only) must be part of the player's pipeline.
    player: AudioPlayer(audioPipeline: audioPipelineFor(ref.read(androidEqualizerProvider))),
  );
  ref.onDispose(service.dispose);
  return service;
});

final playerSnapshotProvider = StreamProvider<PlayerSnapshot>((ref) async* {
  final port = ref.watch(playerPortProvider);
  yield port.snapshot;
  yield* port.snapshots;
});

final playerPositionProvider = StreamProvider<Duration>((ref) async* {
  final port = ref.watch(playerPortProvider);
  yield port.position;
  yield* port.positions;
});
