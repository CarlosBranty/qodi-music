import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../auth/ui/auth_controller.dart';
import '../../device_music/ui/device_music_providers.dart';
import '../../device_music/ui/device_music_view.dart';
import '../../downloads/ui/downloads_controller.dart';
import '../../downloads/ui/downloads_view.dart';
import '../../favorites/ui/favorites_controller.dart';
import '../../playlists/ui/playlist_picker.dart';
import '../../playlists/ui/playlists_controller.dart';
import 'track_actions.dart';

/// Library tab: server playlists, favorites, (native only) downloads and
/// "On this device" music.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, this.initialTab});
  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.read(downloadsControllerProvider.notifier).supported;
    final server = ref.watch(serverConnectedProvider);
    final device = ref.watch(deviceMusicSupportedProvider);
    // Without a server session only the device section is shown.
    final l = context.l10n;
    final tabs = [
      if (server) ...[l.playlists, l.favorites, if (offline) l.downloads],
      if (device) l.onThisDevice,
    ];
    final initial = switch (initialTab) {
      'favorites' when server => 1,
      'downloads' when server && offline => 2,
      'device' when device => tabs.length - 1,
      _ => 0,
    };
    if (tabs.isEmpty) {
      return Center(child: Text(l.libraryNeedsServer));
    }
    final text = Theme.of(context).textTheme;
    return DefaultTabController(
      key: ValueKey('${tabs.length}-$initial'),
      length: tabs.length,
      initialIndex: initial,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(l.yourLibrary, style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: QodiTokens.orange,
            indicatorColor: QodiTokens.orange,
            unselectedLabelColor: QodiColors.of(context).textMuted,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tabs: [for (final t in tabs) Tab(text: t)],
          ),
          Expanded(
            child: TabBarView(
              children: [
                if (server) ...[
                  const _PlaylistsTab(),
                  const _FavoritesTab(),
                  if (offline) const DownloadsView(),
                ],
                if (device) const DeviceMusicView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = QodiColors.of(context);
    final playlists = ref.watch(playlistsControllerProvider);
    Future<void> create() async {
      final name = await askPlaylistName(context);
      if (name == null) return;
      try {
        await ref.read(playlistsControllerProvider.notifier).create(name);
      } catch (_) {
        if (context.mounted) showSnack(context, context.l10n.createPlaylistFailed);
      }
    }

    return playlists.when(
      data: (list) => ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: QodiTokens.orange,
                borderRadius: BorderRadius.circular(QodiTokens.radiusM),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
            ),
            title: Text(context.l10n.newPlaylist, style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: create,
          ),
          for (final p in list)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: CoverArt(
                seed: p.id,
                trackId: p.coverTrackId,
                size: 56,
                icon: Icons.queue_music_rounded,
              ),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${context.l10n.songCount(p.trackCount)} • ${formatDuration(Duration(milliseconds: p.durationMs))}',
                  style: TextStyle(color: c.textMuted)),
              onTap: () => context.go('/library/playlist/${p.id}'),
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: QodiTokens.orange)),
      error: (e, _) => Center(child: Text(context.l10n.playlistsLoadFailedDetail('$e'), textAlign: TextAlign.center)),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(favoritesControllerProvider).when(
          data: (list) => list.isEmpty
              ? Center(child: Text(context.l10n.noFavoritesYet))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => ConnectedTrackTile(track: list[i], queue: list, index: i),
                ),
          loading: () => const Center(child: CircularProgressIndicator(color: QodiTokens.orange)),
          error: (e, _) => Center(child: Text(context.l10n.favoritesLoadFailedDetail('$e'), textAlign: TextAlign.center)),
        );
  }
}
