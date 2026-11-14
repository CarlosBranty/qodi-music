import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/arc_waveform_seekbar.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/vinyl_cover.dart';
import '../../favorites/ui/favorites_controller.dart';
import '../../library/domain/entities.dart';
import '../../library/ui/library_providers.dart';
import '../../library/ui/track_actions.dart';
import '../../lyrics/ui/lyrics_sheet.dart';
import '../../playlists/ui/playlist_picker.dart';
import '../domain/play_queue.dart';
import '../domain/player_port.dart';
import 'player_providers.dart';
import 'queue_sheet.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(playerSnapshotProvider).value ?? PlayerSnapshot.empty;
    final track = snap.current;
    final c = QodiColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  Expanded(
                    child: Text('Now Playing',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_horiz_rounded),
                    enabled: track != null,
                    onSelected: (v) {
                      if (track == null) return;
                      switch (v) {
                        case 'queue':
                          showQueueSheet(context);
                        case 'playlist':
                          showPlaylistPicker(context, ref, [track]);
                        case 'more':
                          showTrackActions(context, ref, track);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'queue', child: Text('Queue')),
                      PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
                      PopupMenuItem(value: 'more', child: Text('More actions')),
                    ],
                  ),
                ],
              ),
            ),
            if (track == null)
              Expanded(
                child: Center(
                  child: Text('Nothing is playing', style: TextStyle(color: c.textMuted)),
                ),
              )
            else ...[
              Expanded(child: _CoverCarousel(snapshot: snap)),
              _Seekbar(track: track, duration: snap.duration),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Text(track.title,
                        key: const Key('np-title'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800, color: c.text)),
                    const SizedBox(height: 4),
                    Text(track.artist,
                        key: const Key('np-artist'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textMuted, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _Controls(snapshot: snap, track: track),
              _LyricsHandle(track: track),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoverCarousel extends ConsumerStatefulWidget {
  const _CoverCarousel({required this.snapshot});
  final PlayerSnapshot snapshot;

  @override
  ConsumerState<_CoverCarousel> createState() => _CoverCarouselState();
}

class _CoverCarouselState extends ConsumerState<_CoverCarousel> {
  late PageController _pages =
      PageController(viewportFraction: 0.72, initialPage: widget.snapshot.queuePosition.clamp(0, 1 << 30));
  bool _programmatic = false;

  @override
  void didUpdateWidget(_CoverCarousel old) {
    super.didUpdateWidget(old);
    final target = widget.snapshot.queuePosition;
    if (target >= 0 && _pages.hasClients && _pages.page?.round() != target) {
      _programmatic = true;
      _pages
          .animateToPage(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic)
          .whenComplete(() => _programmatic = false);
    } else if (!_pages.hasClients && target >= 0) {
      _pages.dispose();
      _pages = PageController(viewportFraction: 0.72, initialPage: target);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final queue = s.queue.isEmpty && s.current != null ? [s.current!] : s.queue;
    return LayoutBuilder(builder: (context, c) {
      final size = (c.maxHeight * 0.92).clamp(120.0, c.maxWidth * 0.72);
      return PageView.builder(
        controller: _pages,
        itemCount: queue.length,
        onPageChanged: (i) {
          if (!_programmatic && i != s.queuePosition) {
            ref.read(playerPortProvider).jumpTo(i);
          }
        },
        itemBuilder: (context, i) {
          final t = queue[i];
          final isCurrent = i == s.queuePosition || (s.queue.isEmpty && i == 0);
          return Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 250),
              scale: isCurrent ? 1 : 0.82,
              child: isCurrent
                  ? VinylCover(
                      key: ValueKey('vinyl-${t.id}'),
                      seed: t.albumId,
                      trackId: t.hasCover ? t.id : null,
                      size: size,
                      spinning: s.playing,
                      labelFraction: 0.5,
                    )
                  : CoverArt(
                      seed: t.albumId,
                      trackId: t.hasCover ? t.id : null,
                      size: size,
                      radius: QodiTokens.radiusXL,
                    ),
            ),
          );
        },
      );
    });
  }
}

class _Seekbar extends ConsumerWidget {
  const _Seekbar({required this.track, required this.duration});
  final Track track;
  final Duration duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playerPositionProvider).value ?? Duration.zero;
    final total = duration > Duration.zero ? duration : track.duration;
    final peaks = ref.watch(waveformProvider(track.id)).value ?? List<double>.filled(120, 0.25);
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final c = QodiColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          ArcWaveformSeekbar(
            peaks: peaks,
            progress: progress,
            height: 110,
            onSeek: (p) => ref.read(playerPortProvider).seek(total * p),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(formatClock(position),
                    key: const Key('np-elapsed'),
                    style: const TextStyle(color: QodiTokens.orange, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(formatClock(total), style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.snapshot, required this.track});
  final PlayerSnapshot snapshot;
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final port = ref.read(playerPortProvider);
    final c = QodiColors.of(context);
    final favLoaded = ref.watch(favoritesControllerProvider).hasValue;
    final fav = favLoaded ? ref.watch(favoriteIdsProvider).contains(track.id) : track.favorite;
    final repeat = snapshot.repeat;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Repeat: ${repeat.name}',
            onPressed: () => port.setRepeat(QueueRepeat.values[(repeat.index + 1) % QueueRepeat.values.length]),
            icon: Icon(repeat == QueueRepeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                color: repeat == QueueRepeat.off ? c.textMuted : QodiTokens.orange),
          ),
          IconButton(
            tooltip: 'Previous',
            iconSize: 34,
            onPressed: port.previous,
            icon: Icon(Icons.skip_previous_rounded, color: c.text),
          ),
          SizedBox(
            width: 78,
            height: 78,
            child: Material(
              color: QodiTokens.orange,
              shape: const CircleBorder(),
              elevation: 6,
              shadowColor: QodiTokens.orange.withValues(alpha: 0.5),
              child: InkWell(
                key: const Key('play-pause'),
                customBorder: const CircleBorder(),
                onTap: port.togglePlay,
                child: Semantics(
                  button: true,
                  label: snapshot.playing ? 'Pause' : 'Play',
                  child: Icon(
                    snapshot.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next',
            iconSize: 34,
            onPressed: port.next,
            icon: Icon(Icons.skip_next_rounded, color: c.text),
          ),
          IconButton(
            key: const Key('np-favorite'),
            tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () => ref.read(favoritesControllerProvider.notifier).toggle(track).catchError((Object _) {
              if (context.mounted) showSnack(context, 'Could not update favorites');
            }),
            icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: QodiTokens.orange),
          ),
        ],
      ),
    );
  }
}

class _LyricsHandle extends StatelessWidget {
  const _LyricsHandle({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showLyricsSheet(context, track),
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -100) showLyricsSheet(context, track);
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Column(
          children: [
            Icon(Icons.keyboard_arrow_up_rounded, color: c.textMuted),
            Text('Lyrics', style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
