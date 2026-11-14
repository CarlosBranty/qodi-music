import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../device_music/domain/device_track.dart';
import '../../device_music/ui/device_playlist_picker.dart';
import '../../downloads/ui/downloads_controller.dart';
import '../../downloads/ui/offline_status.dart';
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
    final showOffline = downloads.supported && !device;
    final offline = showOffline ? OfflineSummary.of(tracks, ref.watch(downloadsControllerProvider)) : null;
    final l = context.l10n;
    final offlineLabel = offline?.label(l);
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
          if (offlineLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              key: const Key('collection-offline'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const OfflineBadge(size: 16),
                const SizedBox(width: 6),
                Text(offlineLabel,
                    style: const TextStyle(color: QodiTokens.orange, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: tracks.isEmpty ? null : () => player.playTracks(tracks),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l.play),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: l.shuffle,
                onPressed: tracks.isEmpty
                    ? null
                    : () async {
                        await player.setShuffle(true);
                        await player.playTracks(tracks, startIndex: Random().nextInt(tracks.length));
                      },
                icon: const Icon(Icons.shuffle_rounded),
              ),
              IconButton.filledTonal(
                tooltip: l.addToPlaylist,
                onPressed: tracks.isEmpty
                    ? null
                    : () => device
                        ? showDevicePlaylistPicker(context, ref, tracks)
                        : showPlaylistPicker(context, ref, tracks),
                icon: const Icon(Icons.playlist_add_rounded),
              ),
              if (offline != null)
                offline.downloading > 0
                    ? Padding(
                        key: const Key('collection-download-progress'),
                        padding: const EdgeInsets.all(8),
                        child: SizedBox.square(
                          dimension: 32,
                          child: CircularProgressIndicator(
                              value: offline.progress, strokeWidth: 3, color: QodiTokens.orange),
                        ),
                      )
                    : IconButton.filledTonal(
                        tooltip: offline.complete ? l.downloaded : l.downloadAll,
                        onPressed: tracks.isEmpty || offline.complete
                            ? null
                            : () {
                                showSnack(context, l.downloadingSongs(tracks.length));
                                downloads.downloadAll(tracks);
                              },
                        icon: Icon(offline.complete ? Icons.download_done_rounded : Icons.download_rounded),
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.album)),
      body: detail.when(
        data: (d) {
          final a = d.album;
          final meta = [
            a.artist,
            if (a.year != null) '${a.year}',
            l.songCount(a.trackCount),
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
        error: (e, _) => Center(child: Text(l.albumLoadFailed('$e'), textAlign: TextAlign.center)),
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.artist)),
      body: tracks.when(
        data: (list) {
          final name = list.isEmpty ? l.artist : list.first.artist;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: CollectionHeader(
                  seed: artistId,
                  title: name,
                  subtitle: '${l.albumCount(albums.length)} • ${l.songCount(list.length)}',
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
        error: (e, _) => Center(child: Text(l.artistLoadFailed('$e'), textAlign: TextAlign.center)),
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
