import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/vinyl_cover.dart';
import '../../auth/ui/auth_controller.dart';
import '../../favorites/ui/favorites_controller.dart';
import '../../library/domain/entities.dart';
import '../../library/ui/library_providers.dart';
import '../../library/ui/track_actions.dart';
import '../../player/ui/player_providers.dart';
import '../../playlists/domain/playlist.dart';
import '../../playlists/ui/playlists_controller.dart';
import '../../stats/ui/stats_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    final name = session?.user.username ?? '';
    final playlists = ref.watch(playlistsControllerProvider);
    final favorites = ref.watch(favoritesControllerProvider);
    final history = ref.watch(historyProvider);
    final c = QodiColors.of(context);
    final text = Theme.of(context).textTheme;

    List<Track> recent = history;
    if (recent.isEmpty) {
      recent = ref.watch(weeklyStatsProvider).value?.topTracks.map((t) => t.track).toList() ?? const [];
    }

    return RefreshIndicator(
      color: QodiTokens.orange,
      onRefresh: () async {
        ref.invalidate(playlistsControllerProvider);
        ref.invalidate(favoritesControllerProvider);
        ref.invalidate(weeklyStatsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: QodiTokens.orange,
                    borderRadius: BorderRadius.circular(QodiTokens.radiusS + 2),
                  ),
                  child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                      style: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back,', style: text.bodyMedium?.copyWith(color: c.textMuted)),
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text('What do you want\nto listen today?',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.15)),
          ),
          SectionHeader('Playlist', actionLabel: 'View all', onAction: () => context.go('/library')),
          SizedBox(
            height: 210,
            child: playlists.when(
              data: (list) => list.isEmpty
                  ? _EmptyHint('No playlists yet. Create one in Library.', onTap: () => context.go('/library'))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (_, i) => _PlaylistCard(list[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator(color: QodiTokens.orange)),
              error: (e, _) => _EmptyHint('Could not load playlists'),
            ),
          ),
          if (recent.isNotEmpty) ...[
            const SectionHeader('Recently played'),
            SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: recent.length.clamp(0, 12),
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, i) => VinylCard(
                  track: recent[i],
                  onTap: () => ref.read(playerPortProvider).playTracks(recent, startIndex: i),
                ),
              ),
            ),
          ],
          SectionHeader('Favorites', actionLabel: 'View all', onAction: () => context.go('/library?tab=favorites')),
          favorites.when(
            data: (list) => list.isEmpty
                ? _EmptyHint('Tap the heart on any song to keep it here.')
                : Column(
                    children: [
                      for (var i = 0; i < list.length && i < 6; i++)
                        ConnectedTrackTile(track: list[i], queue: list, index: i),
                    ],
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: QodiTokens.orange)),
            ),
            error: (e, _) => _EmptyHint('Could not load favorites'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text, {this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: InkWell(
          onTap: onTap,
          child: Text(text, style: TextStyle(color: QodiColors.of(context).textMuted)),
        ),
      );
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard(this.playlist);
  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    return GestureDetector(
      onTap: () => context.go('/library/playlist/${playlist.id}'),
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(
              seed: playlist.id,
              trackId: playlist.coverTrackId,
              size: 150,
              radius: QodiTokens.radiusL,
              icon: Icons.queue_music_rounded,
            ),
            const SizedBox(height: 8),
            Text(playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(songsLabel(playlist.trackCount), style: TextStyle(color: c.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Vinyl record overlapping the top of a beige card (reference image 1).
class VinylCard extends StatelessWidget {
  const VinylCard({super.key, required this.track, this.onTap});
  final Track track;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    final text = Theme.of(context).textTheme;
    final minutes = track.duration.inMinutes;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 168,
        child: Stack(
          children: [
            Positioned.fill(
              top: 62,
              child: Container(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(QodiTokens.radiusL),
                ),
                padding: const EdgeInsets.fromLTRB(14, 74, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((track.genre ?? track.album).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: QodiTokens.orange, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    Text(track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.15)),
                    const Spacer(),
                    Text('${minutes < 1 ? 1 : minutes} min • ${track.artist}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: VinylCover(
                seed: track.albumId,
                trackId: track.hasCover ? track.id : null,
                size: 128,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
