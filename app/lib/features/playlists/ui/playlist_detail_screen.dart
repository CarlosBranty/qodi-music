import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/track_tile.dart';
import '../../library/domain/entities.dart';
import '../../library/ui/album_detail_screen.dart';
import '../../library/ui/track_actions.dart';
import '../../player/ui/player_providers.dart';
import 'playlist_picker.dart';
import 'playlists_controller.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  /// Local order while a reorder/remove is being saved.
  List<Track>? _pending;

  PlaylistsController get _controller => ref.read(playlistsControllerProvider.notifier);

  Future<void> _save(List<Track> tracks) async {
    setState(() => _pending = tracks);
    try {
      await _controller.setTracks(widget.playlistId, tracks);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save the playlist');
    }
    if (mounted) setState(() => _pending = null);
  }

  Future<void> _rename(String current) async {
    final name = await askPlaylistName(context, title: 'Rename playlist', initial: current, action: 'Save');
    if (name == null) return;
    try {
      await _controller.rename(widget.playlistId, name);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not rename');
    }
  }

  Future<void> _delete(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text('"$name" will be deleted. Songs stay in your library.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _controller.delete(widget.playlistId);
      if (mounted) context.go('/library');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(playlistDetailProvider(widget.playlistId));
    final name = detail.value?.playlist.name ?? 'Playlist';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlist'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Playlist options',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (v) => v == 'rename' ? _rename(name) : _delete(name),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: detail.when(
        data: (d) {
          final tracks = _pending ?? d.tracks;
          final p = d.playlist;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: CollectionHeader(
                  seed: p.id,
                  title: p.name,
                  subtitle: '${songsLabel(tracks.length)} • ${formatDuration(Duration(milliseconds: p.durationMs))}',
                  tracks: tracks,
                  coverTrackId: p.coverTrackId,
                  icon: Icons.queue_music_rounded,
                ),
              ),
              if (tracks.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Empty playlist. Long-press any song and choose "Add to playlist".',
                        textAlign: TextAlign.center),
                  ),
                ),
              SliverReorderableList(
                itemCount: tracks.length,
                onReorderItem: (oldIndex, newIndex) {
                  final list = List.of(tracks);
                  list.insert(newIndex, list.removeAt(oldIndex));
                  _save(list);
                },
                itemBuilder: (context, i) {
                  final t = tracks[i];
                  return Material(
                    key: ValueKey('${t.id}-$i'),
                    color: Colors.transparent,
                    child: TrackTile(
                      track: t,
                      onTap: () => ref.read(playerPortProvider).playTracks(tracks, startIndex: i),
                      onLongPress: () => showTrackActions(context, ref, t),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Remove from playlist',
                            icon: Icon(Icons.remove_circle_outline_rounded, color: QodiColors.of(context).textMuted),
                            onPressed: () => _save(List.of(tracks)..removeAt(i)),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle_rounded, color: QodiColors.of(context).textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: QodiTokens.orange)),
        error: (e, _) => Center(child: Text('Could not load playlist\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}
