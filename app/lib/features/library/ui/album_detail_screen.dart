import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../device_music/domain/device_track.dart';
import '../../device_music/ui/device_playlist_picker.dart';
import '../../downloads/ui/downloads_controller.dart';
import '../../player/ui/player_providers.dart';
import '../../playlists/ui/playlist_picker.dart';
import '../domain/entities.dart';
import 'library_providers.dart';
import 'track_actions.dart';

/// Header + track list used by album, artist and playlist screens.
class CollectionHeader extends ConsumerWidget {
  const CollectionHeader({
    super.key,
    required this.seed,
    required this.title,
    required this.subtitle,
    required this.tracks,
    this.coverTrackId,
    this.icon = Icons.album_rounded,
    this.circle = false,
  });

  final String seed;
  final String title;
  final String subtitle;
  final List<Track> tracks;
  final String? coverTrackId;
  final IconData icon;
  final bool circle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = QodiColors.of(context);
    final text = Theme.of(context).textTheme;
    final downloads = ref.read(downloadsControllerProvider.notifier);
    final player = ref.read(playerPortProvider);
    // Device collections use local playlists and cannot be downloaded.
    final device = tracks.isNotEmpty && tracks.every((t) => isDeviceTrackId(t.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        children: [
          CoverArt(seed: seed, trackId: coverTrackId, size: 200, radius: QodiTokens.radiusXL, circle: circle, icon: icon),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: tracks.isEmpty ? null : () => player.playTracks(tracks),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play'),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Shuffle',
                onPressed: tracks.isEmpty
                    ? null
                    : () async {
                        await player.setShuffle(true);
                        await player.playTracks(tracks, startIndex: Random().nextInt(tracks.length));
                      },
                icon: const Icon(Icons.shuffle_rounded),
              ),
              IconButton.filledTonal(
                tooltip: 'Add to playlist',
                onPressed: tracks.isEmpty
                    ? null
                    : () => device
                        ? showDevicePlaylistPicker(context, ref, tracks)
                        : showPlaylistPicker(context, ref, tracks),
                icon: const Icon(Icons.playlist_add_rounded),
              ),
              if (downloads.supported && !device)
                IconButton.filledTonal(
                  tooltip: 'Download all',
                  onPressed: tracks.isEmpty
                      ? null
                      : () {
                          showSnack(context, 'Downloading ${songsLabel(tracks.length).toLowerCase()}');
                          downloads.downloadAll(tracks);
                        },
                  icon: const Icon(Icons.download_rounded),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.albumId});
  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(albumDetailProvider(albumId));
    return Scaffold(
      appBar: AppBar(title: const Text('Album')),
      body: detail.when(
        data: (d) {
          final a = d.album;
          final meta = [
            a.artist,
            if (a.year != null) '${a.year}',
            songsLabel(a.trackCount),
            formatDuration(Duration(milliseconds: a.durationMs)),
          ].join(' • ');
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: d.tracks.length + 1,
            itemBuilder: (_, i) => i == 0
                ? CollectionHeader(
                    seed: a.id, title: a.title, subtitle: meta, tracks: d.tracks, coverTrackId: a.coverTrackId)
                : ConnectedTrackTile(
                    track: d.tracks[i - 1],
                    queue: d.tracks,
                    index: i - 1,
                    leading: SizedBox(
                      width: 32,
                      child: Text('${d.tracks[i - 1].trackNumber ?? i}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: QodiColors.of(context).textMuted, fontWeight: FontWeight.w700)),
                    ),
                  ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: QodiTokens.orange)),
        error: (e, _) => Center(child: Text('Could not load album\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}

class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.artistId});
  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(artistTracksProvider(artistId));
    final albums = ref.watch(artistAlbumsProvider(artistId)).value ?? const <Album>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Artist')),
      body: tracks.when(
        data: (list) {
          final name = list.isEmpty ? 'Artist' : list.first.artist;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: CollectionHeader(
                  seed: artistId,
                  title: name,
                  subtitle: '${albums.length} albums • ${songsLabel(list.length)}',
                  tracks: list,
                  circle: true,
                  icon: Icons.person_rounded,
                  coverTrackId: list.where((t) => t.hasCover).firstOrNull?.id,
                ),
              ),
              if (albums.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: albums.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => SizedBox(width: 130, child: _MiniAlbum(albums[i])),
                    ),
                  ),
                ),
              SliverList.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => ConnectedTrackTile(track: list[i], queue: list, index: i),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: QodiTokens.orange)),
        error: (e, _) => Center(child: Text('Could not load artist\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}

class _MiniAlbum extends StatelessWidget {
  const _MiniAlbum(this.album);
  final Album album;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.go('/explore/album/${album.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(seed: album.id, trackId: album.coverTrackId, size: 130, radius: QodiTokens.radiusM),
            const SizedBox(height: 6),
            Text(album.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (album.year != null)
              Text('${album.year}', style: TextStyle(color: QodiColors.of(context).textMuted, fontSize: 12)),
          ],
        ),
      );
}
