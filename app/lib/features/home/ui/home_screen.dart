import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/vinyl_cover.dart';
import '../../auth/ui/auth_controller.dart';
import '../../device_music/domain/device_music_source.dart';
import '../../device_music/domain/device_track.dart';
import '../../device_music/ui/device_music_providers.dart';
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
    final server = session != null;
    final deviceSupported = ref.watch(deviceMusicSupportedProvider);
    final name = session?.user.username ?? 'Listener';
    final history = ref.watch(historyProvider);
    final c = QodiColors.of(context);
    final text = Theme.of(context).textTheme;

    // Device-only mode: local history of device songs, no server calls.
    List<Track> recent = server ? history : history.where((t) => isDeviceTrackId(t.id)).toList();
    if (recent.isEmpty && server) {
      recent = ref.watch(weeklyStatsProvider).value?.topTracks.map((t) => t.track).toList() ?? const [];
    }

    return RefreshIndicator(
      color: QodiTokens.orange,
      onRefresh: () async {
        if (server) {
          ref.invalidate(playlistsControllerProvider);
          ref.invalidate(favoritesControllerProvider);
          ref.invalidate(weeklyStatsProvider);
        } else {
          await ref.read(deviceLibraryProvider.notifier).rescan();
        }
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
                      Text(server ? 'Welcome back,' : 'Offline mode,',
                          style: text.bodyMedium?.copyWith(color: c.textMuted)),
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
          if (deviceSupported) const DeviceShortcutCard(),
          if (server) const _ServerPlaylists() else if (deviceSupported) const _DevicePlaylists(),
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
          if (server) const _ServerFavorites() else if (deviceSupported) const _DeviceFavorites(),
        ],
      ),
    );
  }
}

class _ServerPlaylists extends ConsumerWidget {
  const _ServerPlaylists();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}

class _DevicePlaylists extends ConsumerWidget {
  const _DevicePlaylists();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(devicePlaylistsProvider).value ?? const [];
    final byId = ref.watch(deviceTrackByIdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Playlist', actionLabel: 'View all', onAction: () => context.go('/library?tab=device')),
        if (list.isEmpty)
          _EmptyHint('No device playlists yet. Create one in Library.', onTap: () => context.go('/library?tab=device'))
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final tracks = resolvePlaylistTracks(list[i], byId);
                return _PlaylistCard(
                  Playlist(
                    id: list[i].id,
                    name: list[i].name,
                    trackCount: tracks.length,
                    durationMs: tracks.fold(0, (s, t) => s + t.durationMs),
                    coverTrackId: tracks.where((t) => t.hasCover).firstOrNull?.id,
                    createdAt: list[i].createdAt,
                    updatedAt: list[i].updatedAt,
                  ),
                  route: '/library/device/playlist/${list[i].id}',
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ServerFavorites extends ConsumerWidget {
  const _ServerFavorites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    );
  }
}

class _DeviceFavorites extends ConsumerWidget {
  const _DeviceFavorites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(deviceFavoriteTracksProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Favorites', actionLabel: 'View all', onAction: () => context.go('/library?tab=device')),
        if (list.isEmpty)
          _EmptyHint('Tap the heart on any song to keep it here.')
        else
          for (var i = 0; i < list.length && i < 6; i++) ConnectedTrackTile(track: list[i], queue: list, index: i),
      ],
    );
  }
}

/// Shortcut to the "On this device" section of the Library.
class DeviceShortcutCard extends ConsumerWidget {
  const DeviceShortcutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceLibraryProvider).value;
    final count = state?.tracks.length ?? 0;
    final subtitle = state == null
        ? 'Loading…'
        : state.scanning
            ? 'Scanning your music…'
            : !state.permission.allowed && count == 0
                ? 'Allow access to play your music files'
                : songsLabel(count);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Material(
        color: QodiTokens.navy,
        borderRadius: BorderRadius.circular(QodiTokens.radiusL),
        child: InkWell(
          key: const Key('device-shortcut'),
          borderRadius: BorderRadius.circular(QodiTokens.radiusL),
          onTap: () => context.go('/library?tab=device'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const VinylCover(seed: 'device', size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('On this device',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: QodiTokens.orange, shape: BoxShape.circle),
                  child: const Icon(Icons.phone_android_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
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
  const _PlaylistCard(this.playlist, {this.route});
  final Playlist playlist;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    return GestureDetector(
      onTap: () => context.go(route ?? '/library/playlist/${playlist.id}'),
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
