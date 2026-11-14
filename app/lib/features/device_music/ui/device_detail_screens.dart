import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../../library/ui/album_detail_screen.dart';
import '../../library/ui/track_actions.dart';
import '../../playlists/ui/playlist_picker.dart';
import '../domain/device_library.dart';
import 'device_music_providers.dart';

Widget _notFound(String what) => Center(child: Text('$what is no longer on this device'));

class DeviceAlbumScreen extends ConsumerWidget {
  const DeviceAlbumScreen({super.key, required this.albumId});
  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = albumTracks(ref.watch(deviceTracksProvider), albumId);
    final album = ref.watch(deviceAlbumsProvider).where((a) => a.id == albumId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Album')),
      body: album == null
          ? _notFound('This album')
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
                        songsLabel(album.trackCount),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Artist')),
      body: tracks.isEmpty
          ? _notFound('This artist')
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: tracks.length + 1,
              itemBuilder: (_, i) => i == 0
                  ? CollectionHeader(
                      seed: artistId,
                      title: tracks.first.artistId == artistId ? tracks.first.artist : tracks.first.albumArtist,
                      subtitle: '${albums.length} albums • ${songsLabel(tracks.length)}',
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
    if (playlist == null) {
      return Scaffold(appBar: AppBar(title: const Text('Playlist')), body: _notFound('This playlist'));
    }
    final tracks = resolvePlaylistTracks(playlist, ref.watch(deviceTrackByIdProvider));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlist'),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              final name = await askPlaylistName(context,
                  title: 'Rename playlist', initial: playlist.name, action: 'Save');
              if (name != null) await controller.rename(playlistId, name);
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete playlist?'),
                  content: Text('"${playlist.name}" will be deleted. Songs stay on your device.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
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
              subtitle: '${songsLabel(tracks.length)} • '
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
              tooltip: 'Remove from playlist',
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: () => controller.setTracks(playlistId, [...tracks]..removeAt(i - 1)),
            ),
          );
        },
      ),
    );
  }
}
