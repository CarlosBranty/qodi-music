import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/track_tile.dart';
import '../../downloads/ui/downloads_controller.dart';
import '../../downloads/ui/offline_status.dart';
import '../../device_music/domain/device_track.dart';
import '../../device_music/ui/device_playlist_picker.dart';
import '../../favorites/ui/track_favorite.dart';
import '../../player/ui/player_providers.dart';
import '../../playlists/ui/playlist_picker.dart';
import '../domain/audio_quality.dart';
import '../domain/entities.dart';
import 'quality_text.dart';

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Bottom sheet with actions for a track (queue, playlist, download, ...).
Future<void> showTrackActions(BuildContext context, WidgetRef ref, Track track) {
  final downloads = ref.read(downloadsControllerProvider.notifier);
  final device = isDeviceTrackId(track.id);
  final l = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) {
      final downloaded = ref.read(downloadsControllerProvider).isDownloaded(track.id);
      void close() => Navigator.of(sheet).pop();
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TrackTile(track: track),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.queue_play_next_rounded),
                title: Text(l.playNext),
                onTap: () {
                  close();
                  ref.read(playerPortProvider).playNext(track);
                  showSnack(context, l.playingNext(track.title));
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(l.addToQueue),
                onTap: () {
                  close();
                  ref.read(playerPortProvider).enqueue(track);
                  showSnack(context, l.addedToQueue);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: Text(l.addToPlaylist),
                onTap: () {
                  close();
                  device ? showDevicePlaylistPicker(context, ref, [track]) : showPlaylistPicker(context, ref, [track]);
                },
              ),
              if (downloads.supported && !device)
                ListTile(
                  leading: Icon(downloaded ? Icons.delete_outline_rounded : Icons.download_rounded),
                  title: Text(downloaded ? l.removeDownload : l.download),
                  onTap: () {
                    close();
                    downloaded ? downloads.delete(track.id) : downloads.download(track);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.album_rounded),
                title: Text(l.goToAlbum(track.album)),
                onTap: () {
                  close();
                  context.go(device ? '/library/device/album/${track.albumId}' : '/explore/album/${track.albumId}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text(l.goToArtist(track.artist)),
                onTap: () {
                  close();
                  context.go(device ? '/library/device/artist/${track.artistId}' : '/explore/artist/${track.artistId}');
                },
              ),
              ListTile(
                key: const Key('track-info'),
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(l.trackInfo),
                subtitle: Text(qualityLabel(track)),
                onTap: () {
                  close();
                  showTrackInfo(context, track);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Dialog with the audio properties of [track] (format, bitrate, ...).
Future<void> showTrackInfo(BuildContext context, Track track) {
  final l = context.l10n;
  final rows = trackInfoRows(l, track, formatSize: (b) => formatBytes(b, locale: l.localeName));
  final badge = qualityBadgeText(l, qualityTier(track));
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                badge,
                key: const Key('track-info-badge'),
                style: const TextStyle(color: QodiTokens.orange, fontWeight: FontWeight.w800),
              ),
            ),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: TextStyle(color: QodiColors.of(dialog).textMuted)),
                  ),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(MaterialLocalizations.of(dialog).closeButtonLabel),
        ),
      ],
    ),
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
    final playing = current == track.id && ref.watch(playerSnapshotProvider.select((s) => s.value?.playing ?? false));
    final downloading = ref.watch(downloadsControllerProvider.select((s) => s.isDownloading(track.id)));
    final offline = ref.watch(trackAvailableOfflineProvider(track.id));
    return TrackTile(
      track: track,
      highlighted: current == track.id,
      playing: playing,
      favorite: fav,
      leading: leading,
      trailing:
          trailing ??
          (downloading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: QodiTokens.orange),
                )
              : offline
              ? const OfflineBadge()
              : null),
      onFavorite: () => toggleTrackFavorite(ref, track).catchError((Object _) {
        if (context.mounted) showSnack(context, context.l10n.favoritesUpdateFailed);
      }),
      onTap: () => ref.read(playerPortProvider).playTracks(queue, startIndex: index),
      onMore: () => showTrackActions(context, ref, track),
    );
  }
}
