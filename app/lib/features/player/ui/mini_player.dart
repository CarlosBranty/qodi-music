import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/vinyl_cover.dart';
import '../../downloads/ui/offline_status.dart';
import 'player_providers.dart';

/// Compact player shown above the nav bar while something is loaded.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(playerSnapshotProvider).value;
    final track = snap?.current;
    if (snap == null || track == null) return const SizedBox.shrink();
    final c = QodiColors.of(context);
    final port = ref.read(playerPortProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: c.cardStrong,
        elevation: 4,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(QodiTokens.radiusL),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/now-playing'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
                child: Row(
                  children: [
                    OfflineCoverBadge(
                      trackId: track.id,
                      badgeSize: 16,
                      inset: 0,
                      child: VinylCover(
                        seed: track.albumId,
                        trackId: track.hasCover ? track.id : null,
                        size: 46,
                        spinning: snap.playing,
                        labelFraction: 0.55,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: snap.playing ? 'Pause' : 'Play',
                      onPressed: port.togglePlay,
                      icon: Icon(snap.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: QodiTokens.orange, size: 38),
                    ),
                    IconButton(
                      tooltip: 'Next',
                      onPressed: port.next,
                      icon: Icon(Icons.skip_next_rounded, color: c.text),
                    ),
                  ],
                ),
              ),
              _MiniProgress(duration: snap.duration > Duration.zero ? snap.duration : track.duration),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniProgress extends ConsumerWidget {
  const _MiniProgress({required this.duration});
  final Duration duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(playerPositionProvider).value ?? Duration.zero;
    final v = duration.inMilliseconds == 0 ? 0.0 : (pos.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    return LinearProgressIndicator(
      value: v,
      minHeight: 3,
      color: QodiTokens.orange,
      backgroundColor: QodiColors.of(context).waveRest,
    );
  }
}
