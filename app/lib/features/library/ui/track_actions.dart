import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/track_tile.dart';
import '../../downloads/ui/downloads_controller.dart';
import '../../device_music/domain/device_track.dart';
import '../../device_music/ui/device_playlist_picker.dart';
import '../../favorites/ui/track_favorite.dart';
import '../../player/ui/player_providers.dart';
import '../../playlists/ui/playlist_picker.dart';
import '../domain/entities.dart';

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Bottom sheet with actions for a track (queue, playlist, download, ...).
Future<void> showTrackActions(BuildContext context, WidgetRef ref, Track track) {
  final downloads = ref.read(downloadsControllerProvider.notifier);
  final device = isDeviceTrackId(track.id);
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) {
      final downloaded = ref.read(downloadsControllerProvider).isDownloaded(track.id);
      void close() => Navigator.of(sheet).pop();
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TrackTile(track: track),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.queue_play_next_rounded),
              title: const Text('Play next'),
              onTap: () {
                close();
                ref.read(playerPortProvider).playNext(track);
                showSnack(context, 'Playing next: ${track.title}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Add to queue'),
              onTap: () {
                close();
                ref.read(playerPortProvider).enqueue(track);
                showSnack(context, 'Added to queue');
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to playlist'),
              onTap: () {
                close();
                device
                    ? showDevicePlaylistPicker(context, ref, [track])
                    : showPlaylistPicker(context, ref, [track]);
              },
            ),
            if (downloads.supported && !device)
              ListTile(
                leading: Icon(downloaded ? Icons.delete_outline_rounded : Icons.download_rounded),
                title: Text(downloaded ? 'Remove download' : 'Download'),
                onTap: () {
                  close();
                  downloaded ? downloads.delete(track.id) : downloads.download(track);
                },
              ),
            ListTile(
              leading: const Icon(Icons.album_rounded),
              title: Text('Go to album · ${track.album}'),
              onTap: () {
                close();
                context.go(device ? '/library/device/album/${track.albumId}' : '/explore/album/${track.albumId}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: Text('Go to artist · ${track.artist}'),
              onTap: () {
                close();
                context.go(device ? '/library/device/artist/${track.artistId}' : '/explore/artist/${track.artistId}');
              },
            ),
          ],
        ),
      );
    },
  );
}

/// [TrackTile] wired to favorites, playback and the actions sheet.
class ConnectedTrackTile extends ConsumerWidget {
  const ConnectedTrackTile({
    super.key,
    required this.track,
    required this.queue,
    required this.index,
    this.leading,
    this.trailing,
  });

  final Track track;

  /// Tracks played when this tile is tapped, starting at [index].
  final List<Track> queue;
  final int index;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = watchIsFavorite(ref, track);
    final current = ref.watch(playerSnapshotProvider.select((s) => s.value?.current?.id));
    final dl = ref.watch(downloadsControllerProvider);
    return TrackTile(
      track: track,
      highlighted: current == track.id,
      favorite: fav,
      leading: leading,
      trailing: trailing ??
          (dl.isDownloading(track.id)
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: QodiTokens.orange))
              : dl.isDownloaded(track.id)
                  ? const Icon(Icons.download_done_rounded, size: 18, color: QodiTokens.orange)
                  : null),
      onFavorite: () => toggleTrackFavorite(ref, track).catchError(
            (Object _) {
              if (context.mounted) showSnack(context, 'Could not update favorites');
            },
          ),
      onTap: () => ref.read(playerPortProvider).playTracks(queue, startIndex: index),
      onMore: () => showTrackActions(context, ref, track),
    );
  }
}
