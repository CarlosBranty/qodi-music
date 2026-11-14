import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../library/domain/entities.dart';
import '../../library/ui/track_actions.dart';
import '../../player/ui/player_providers.dart';
import '../../playlists/ui/playlist_picker.dart';
import '../../search/ui/explore_screen.dart';
import '../domain/device_library.dart';
import '../domain/device_music_source.dart';
import 'device_music_providers.dart';

enum DeviceFilter {
  songs,
  albums,
  artists,
  favorites,
  playlists;

  String label(AppLocalizations l) => switch (this) {
        songs => l.songs,
        albums => l.albums,
        artists => l.artists,
        favorites => l.favorites,
        playlists => l.playlists,
      };
}

/// "On this device": songs / albums / artists / local favorites / local
/// playlists of the music stored on the device, with search and
/// pull-to-refresh rescan.
class DeviceMusicView extends ConsumerStatefulWidget {
  const DeviceMusicView({super.key});

  @override
  ConsumerState<DeviceMusicView> createState() => _DeviceMusicViewState();
}

class _DeviceMusicViewState extends ConsumerState<DeviceMusicView> {
  final _search = TextEditingController();
  DeviceFilter _filter = DeviceFilter.songs;
  String _query = '';
  bool _askedPermission = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _rescan() async {
    final report = await ref.read(deviceLibraryProvider.notifier).rescan();
    if (!mounted || report == null) return;
    final changes = report.added + report.updated + report.removed;
    final l = context.l10n;
    showSnack(context, changes == 0 ? l.deviceUpToDate : l.deviceRescanResult(report.added, report.removed));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(deviceLibraryProvider);
    final state = async.value;
    final l = context.l10n;
    if (state == null) {
      return async.hasError
          ? _Message(icon: Icons.error_outline_rounded, text: l.deviceLoadFailed('${async.error}'))
          : const Center(child: CircularProgressIndicator(color: QodiTokens.orange));
    }
    // First visit on Android: ask for the permission once.
    if (state.permission == DevicePermission.denied && !_askedPermission) {
      _askedPermission = true;
      Future.microtask(() => ref.read(deviceLibraryProvider.notifier).requestAccess());
    }
    if (!state.permission.allowed && state.tracks.isEmpty) return _PermissionState(state.permission);

    final c = QodiColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: TextField(
            key: const Key('device-search'),
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.searchDeviceMusic,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l.clear,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            itemCount: DeviceFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = DeviceFilter.values[i];
              return FilterPill(f.label(l), selected: _filter == f, onTap: () => setState(() => _filter = f));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state.scanning ? l.scanning : l.songsOnDevice(state.tracks.length),
                  style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600),
                ),
              ),
              if (state.scanning)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                      dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: QodiTokens.orange)),
                )
              else
                IconButton(
                  key: const Key('device-rescan'),
                  tooltip: l.rescan,
                  onPressed: _rescan,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: QodiTokens.orange,
            onRefresh: _rescan,
            child: switch (_filter) {
              DeviceFilter.songs => _SongsList(searchTracks(state.tracks, _query), empty: _emptyLibrary(state)),
              DeviceFilter.albums => _AlbumsGrid(_query),
              DeviceFilter.artists => _ArtistsList(_query),
              DeviceFilter.favorites => _SongsList(
                  searchTracks(ref.watch(deviceFavoriteTracksProvider), _query),
                  empty: _Message(icon: Icons.favorite_border_rounded, text: l.deviceFavoritesEmpty),
                ),
              DeviceFilter.playlists => const _PlaylistsList(),
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyLibrary(DeviceLibraryState state) => _query.isNotEmpty
      ? _Message(icon: Icons.search_off_rounded, text: context.l10n.noSongsFound)
      : const _NoMusicState();
}

class _SongsList extends ConsumerWidget {
  const _SongsList(this.tracks, {required this.empty});
  final List<Track> tracks;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) return _scrollable(empty);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: tracks.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(
              children: [
                FilledButton.icon(
                  key: const Key('device-play-all'),
                  onPressed: () => ref.read(playerPortProvider).playTracks(tracks),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(context.l10n.playAll),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: context.l10n.shuffle,
                  onPressed: () async {
                    final player = ref.read(playerPortProvider);
                    await player.setShuffle(true);
                    await player.playTracks(tracks);
                  },
                  icon: const Icon(Icons.shuffle_rounded),
                ),
              ],
            ),
          );
        }
        return ConnectedTrackTile(track: tracks[i - 1], queue: tracks, index: i - 1);
      },
    );
  }
}

class _AlbumsGrid extends ConsumerWidget {
  const _AlbumsGrid(this.query);
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = query.toLowerCase();
    final albums = ref
        .watch(deviceAlbumsProvider)
        .where((a) => q.isEmpty || a.title.toLowerCase().contains(q) || a.artist.toLowerCase().contains(q))
        .toList();
    if (albums.isEmpty) return _scrollable(_Message(icon: Icons.album_rounded, text: context.l10n.noAlbumsFound));
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 16,
        crossAxisSpacing: 14,
        childAspectRatio: 0.74,
      ),
      itemCount: albums.length,
      itemBuilder: (_, i) => AlbumCard(albums[i]),
    );
  }
}

class _ArtistsList extends ConsumerWidget {
  const _ArtistsList(this.query);
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = QodiColors.of(context);
    final q = query.toLowerCase();
    final artists =
        ref.watch(deviceArtistsProvider).where((a) => q.isEmpty || a.name.toLowerCase().contains(q)).toList();
    if (artists.isEmpty) return _scrollable(_Message(icon: Icons.person_rounded, text: context.l10n.noArtistsFound));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24, top: 4),
      itemCount: artists.length,
      itemBuilder: (_, i) {
        final a = artists[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: CoverArt(seed: a.id, size: 48, circle: true, icon: Icons.person_rounded),
          title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${context.l10n.albumCount(a.albumCount)} • ${context.l10n.songCountLower(a.trackCount)}',
              style: TextStyle(color: c.textMuted)),
          onTap: () => context.go('/library/device/artist/${a.id}'),
        );
      },
    );
  }
}

class _PlaylistsList extends ConsumerWidget {
  const _PlaylistsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = QodiColors.of(context);
    final playlists = ref.watch(devicePlaylistsProvider).value ?? const [];
    final byId = ref.watch(deviceTrackByIdProvider);
    Future<void> create() async {
      final name = await askPlaylistName(context);
      if (name == null) return;
      await ref.read(devicePlaylistsProvider.notifier).create(name);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        ListTile(
          key: const Key('device-new-playlist'),
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
          title: Text(context.l10n.newDevicePlaylist, style: const TextStyle(fontWeight: FontWeight.w700)),
          onTap: create,
        ),
        for (final p in playlists)
          Builder(builder: (context) {
            final tracks = resolvePlaylistTracks(p, byId);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: CoverArt(
                seed: p.id,
                trackId: tracks.where((t) => t.hasCover).firstOrNull?.id,
                size: 56,
                icon: Icons.queue_music_rounded,
              ),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${context.l10n.songCount(tracks.length)} • ${formatDuration(Duration(milliseconds: tracks.fold(0, (s, t) => s + t.durationMs)))}',
                style: TextStyle(color: c.textMuted),
              ),
              onTap: () => context.go('/library/device/playlist/${p.id}'),
            );
          }),
      ],
    );
  }
}

/// Keeps pull-to-refresh working on empty states.
Widget _scrollable(Widget child) => LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight), child: child),
      ),
    );

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: QodiTokens.orange),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600)),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class _NoMusicState extends ConsumerWidget {
  const _NoMusicState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(deviceMusicProvider)?.platform;
    final folders = ref.watch(deviceDefaultFoldersProvider).value ?? const [];
    final l = context.l10n;
    final where = platform?.importsFiles ?? false
        ? l.importSongsHint
        : l.noMusicInFolders(folders.isEmpty ? l.theScannedFolders : folders.join(', '));
    return _Message(
      icon: Icons.library_music_rounded,
      text: where,
      action: platform == null
          ? null
          : platform.importsFiles
              ? FilledButton.icon(
                  onPressed: () => importDeviceFiles(context, ref),
                  icon: const Icon(Icons.file_upload_rounded),
                  label: Text(l.importSongs),
                )
              : FilledButton.icon(
                  onPressed: () => addDeviceFolder(context, ref),
                  icon: const Icon(Icons.create_new_folder_rounded),
                  label: Text(l.addFolder),
                ),
    );
  }
}

class _PermissionState extends ConsumerWidget {
  const _PermissionState(this.permission);
  final DevicePermission permission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permanently = permission == DevicePermission.permanentlyDenied;
    final l = context.l10n;
    return _Message(
      icon: Icons.lock_outline_rounded,
      text: permanently ? l.permissionPermanentlyDenied : l.permissionRationale,
      action: FilledButton.icon(
        key: const Key('device-permission'),
        onPressed: () => permanently
            ? ref.read(deviceMusicProvider)?.platform.openPermissionSettings()
            : ref.read(deviceLibraryProvider.notifier).requestAccess(),
        icon: Icon(permanently ? Icons.settings_rounded : Icons.lock_open_rounded),
        label: Text(permanently ? l.openSettings : l.allowAccess),
      ),
    );
  }
}

/// Folder picker → adds a scan folder and rescans.
Future<void> addDeviceFolder(BuildContext context, WidgetRef ref) async {
  final platform = ref.read(deviceMusicProvider)?.platform;
  if (platform == null) return;
  String? folder;
  try {
    folder = await platform.pickFolder(dialogTitle: context.l10n.chooseMusicFolder);
  } catch (_) {
    if (context.mounted) showSnack(context, context.l10n.folderPickerFailed);
    return;
  }
  if (folder == null) return;
  await ref.read(deviceFoldersProvider.notifier).add(folder);
  await ref.read(deviceLibraryProvider.notifier).rescan();
}

/// iOS: imports audio files into the app and rescans.
Future<void> importDeviceFiles(BuildContext context, WidgetRef ref) async {
  final platform = ref.read(deviceMusicProvider)?.platform;
  if (platform == null) return;
  try {
    final n = await platform.importFiles(dialogTitle: context.l10n.importMusic);
    if (context.mounted) showSnack(context, context.l10n.importedSongs(n));
    if (n > 0) await ref.read(deviceLibraryProvider.notifier).rescan();
  } catch (_) {
    if (context.mounted) showSnack(context, context.l10n.importFailed);
  }
}
