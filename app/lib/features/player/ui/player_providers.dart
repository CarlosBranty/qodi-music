import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/core_providers.dart';
import '../../downloads/ui/downloads_controller.dart';
import '../../library/ui/library_providers.dart';
import '../../settings/ui/settings_controllers.dart';
import '../../stats/ui/stats_providers.dart';
import '../data/just_audio_player_service.dart';
import '../domain/player_port.dart';

/// The app-wide player. Tests override it with a fake [PlayerPort].
final playerPortProvider = Provider<PlayerPort>((ref) {
  final urls = ref.read(mediaUrlsProvider);
  final service = JustAudioPlayerService(
    resolveSource: (track) async {
      final local = await ref.read(downloadStoreProvider)?.localPath(track.id);
      if (local != null) return Uri.file(local);
      return urls.stream(track.id, ref.read(qualityProvider));
    },
    recorder: ref.read(playRecorderProvider),
    onPlay: (play) => ref.read(playsReporterProvider).record(play),
    onTrackStarted: (track) => ref.read(historyProvider.notifier).push(track),
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
