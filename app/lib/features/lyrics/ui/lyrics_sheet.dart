import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../library/domain/entities.dart';
import '../../player/ui/player_providers.dart';
import '../domain/lyrics.dart';
import 'lyrics_providers.dart';

Future<void> showLyricsSheet(BuildContext context, Track track) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scroll) => LyricsView(track: track, scrollController: scroll),
      ),
    );

/// Lyrics of [track]. Synced lyrics highlight the active line and follow the
/// playback position; plain lyrics just scroll.
class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key, required this.track, this.scrollController});
  final Track track;
  final ScrollController? scrollController;

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final Map<int, GlobalKey> _keys = {};
  int _lastActive = -1;

  void _follow(int active) {
    if (active == _lastActive || active < 0) return;
    _lastActive = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[active]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.4, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    final lyrics = ref.watch(lyricsProvider(widget.track.id));
    return lyrics.when(
      data: (Lyrics? l) {
        if (l == null || l.lines.isEmpty) {
          return ListView(controller: widget.scrollController, children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No lyrics for this song', textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
            ),
          ]);
        }
        final position = l.synced ? (ref.watch(playerPositionProvider).value ?? Duration.zero) : Duration.zero;
        final active = l.activeLineIndex(position);
        if (l.synced) _follow(active);
        return ListView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
          itemCount: l.lines.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Lyrics · ${widget.track.title}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              );
            }
            final idx = i - 1;
            final isActive = idx == active;
            return Padding(
              key: _keys.putIfAbsent(idx, GlobalKey.new),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: l.synced ? 22 : 17,
                  height: 1.3,
                  fontWeight: l.synced ? FontWeight.w800 : FontWeight.w500,
                  color: !l.synced
                      ? c.text
                      : isActive
                          ? QodiTokens.orange
                          : (idx < active ? c.textMuted : c.text.withValues(alpha: 0.55)),
                ),
                child: Text(l.lines[idx].text.isEmpty ? '♪' : l.lines[idx].text),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: QodiTokens.orange)),
      error: (e, _) => Center(child: Text('Could not load lyrics', style: TextStyle(color: c.textMuted))),
    );
  }
}
