import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/format.dart';
import '../../library/ui/album_detail_screen.dart';
import '../../library/ui/track_actions.dart';
import '../../playlists/ui/playlist_picker.dart';
import '../domain/device_library.dart';
import 'device_music_providers.dart';

Widget _notFound(String message) => Center(child: Text(message));

class DeviceAlbumScreen extends ConsumerWidget {
  const DeviceAlbumScreen({super.key, required this.albumId});
  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = albumTracks(ref.watch(deviceTracksProvider), albumId);
    final album = ref.watch(deviceAlbumsProvider).where((a) => a.id == albumId).firstOrNull;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.album)),
      body: album == null
          ? _notFound(l.albumGone)
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: tracks.length + 1,
              itemBuilder: (_, i) => i == 0
                  ? CollectionHeader(
                      seed: album.id,
                      title: album.title,
                      subtitle: [
                        album.artist,
                        if (album.year != null) '${album.year}',
                        l.songCount(album.trackCount),
                        formatDuration(Duration(milliseconds: album.durationMs)),
                      ].join(' • '),
                      tracks: tracks,
                      coverTrackId: album.coverTrackId,
                    )
                  : ConnectedTrackTile(
                      track: tracks[i - 1],
                      queue: tracks,
                      index: i - 1,
                      leading: SizedBox(
                        width: 32,
                        child: Text('${tracks[i - 1].trackNumber ?? i}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: QodiColors.of(context).textMuted, fontWeight: FontWeight.w700)),
                      ),
                    ),
            ),
    );
  }
}

class DeviceArtistScreen extends ConsumerWidget {
  const DeviceArtistScreen({super.key, required this.artistId});
  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = artistTracks(ref.watch(deviceTracksProvider), artistId);
    final albums = deviceAlbums(tracks);
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.artist)),
      body: tracks.isEmpty
          ? _notFound(l.artistGone)
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: tracks.length + 1,
              itemBuilder: (_, i) => i == 0
                  ? CollectionHeader(
                      seed: artistId,
                      title: tracks.first.artistId == artistId ? tracks.first.artist : tracks.first.albumArtist,
                      subtitle: '${l.albumCount(albums.length)} • ${l.songCount(tracks.length)}',
                      tracks: tracks,
                      circle: true,
                      icon: Icons.person_rounded,
                      coverTrackId: tracks.where((t) => t.hasCover).firstOrNull?.id,
                    )
                  : ConnectedTrackTile(track: tracks[i - 1], queue: tracks, index: i - 1),
            ),
    );
  }
}

class DevicePlaylistScreen extends ConsumerWidget {
  const DevicePlaylistScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(devicePlaylistsProvider).value?.where((p) => p.id == playlistId).firstOrNull;
    final controller = ref.read(devicePlaylistsProvider.notifier);
    final l = context.l10n;
    if (playlist == null) {
      return Scaffold(appBar: AppBar(title: Text(l.playlist)), body: _notFound(l.playlistGone));
    }
    final tracks = resolvePlaylistTracks(playlist, ref.watch(deviceTrackByIdProvider));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.playlist),
        actions: [
          IconButton(
            tooltip: l.rename,
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              final name = await askPlaylistName(context,
                  title: l.renamePlaylist, initial: playlist.name, action: l.save);
              if (name != null) await controller.rename(playlistId, name);
            },
          ),
          IconButton(
            tooltip: l.delete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.deletePlaylistQuestion),
                  content: Text(l.deleteDevicePlaylistBody(playlist.name)),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
                    FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
                  ],
                ),
              );
              if (ok != true) return;
              await controller.delete(playlistId);
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: tracks.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return CollectionHeader(
              seed: playlist.id,
              title: playlist.name,
              subtitle: '${l.songCount(tracks.length)} • '
                  '${formatDuration(Duration(milliseconds: tracks.fold(0, (s, t) => s + t.durationMs)))}',
              tracks: tracks,
              icon: Icons.queue_music_rounded,
              coverTrackId: tracks.where((t) => t.hasCover).firstOrNull?.id,
            );
          }
          final t = tracks[i - 1];
          return ConnectedTrackTile(
            track: t,
            queue: tracks,
            index: i - 1,
            trailing: IconButton(
              tooltip: l.removeFromPlaylist,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: () => controller.setTracks(playlistId, [...tracks]..removeAt(i - 1)),
            ),
          );
        },
      ),
    );
  }
}
