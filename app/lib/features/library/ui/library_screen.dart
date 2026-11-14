import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../downloads/ui/downloads_controller.dart';
import '../../downloads/ui/downloads_view.dart';
import '../../favorites/ui/favorites_controller.dart';
import '../../playlists/ui/playlist_picker.dart';
import '../../playlists/ui/playlists_controller.dart';
import 'track_actions.dart';

/// Library tab: playlists, favorites and (native only) downloads.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, this.initialTab});
  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.read(downloadsControllerProvider.notifier).supported;
    final tabs = ['Playlists', 'Favorites', if (offline) 'Downloads'];
    final initial = switch (initialTab) {
      'favorites' => 1,
      'downloads' when offline => 2,
      _ => 0,
    };
    final text = Theme.of(context).textTheme;
    return DefaultTabController(
      key: ValueKey(initial),
      length: tabs.length,
      initialIndex: initial,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Your Library', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
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
                const _PlaylistsTab(),
                const _FavoritesTab(),
                if (offline) const DownloadsView(),
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
        if (context.mounted) showSnack(context, 'Could not create playlist');
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
            title: const Text('New playlist', style: TextStyle(fontWeight: FontWeight.w700)),
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
                  '${songsLabel(p.trackCount)} • ${formatDuration(Duration(milliseconds: p.durationMs))}',
                  style: TextStyle(color: c.textMuted)),
              onTap: () => context.go('/library/playlist/${p.id}'),
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: QodiTokens.orange)),
      error: (e, _) => Center(child: Text('Could not load playlists\n$e', textAlign: TextAlign.center)),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(favoritesControllerProvider).when(
          data: (list) => list.isEmpty
              ? const Center(child: Text('No favorites yet'))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => ConnectedTrackTile(track: list[i], queue: list, index: i),
                ),
          loading: () => const Center(child: CircularProgressIndicator(color: QodiTokens.orange)),
          error: (e, _) => Center(child: Text('Could not load favorites\n$e', textAlign: TextAlign.center)),
        );
  }
}
