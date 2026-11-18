import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/core_providers.dart';
import '../../auth/ui/auth_controller.dart';
import '../../library/domain/entities.dart';
import '../data/cached_playlist_repository.dart';
import '../data/playlists_api.dart';
import '../domain/playlist.dart';

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final settings = ref.watch(settingsStoreProvider);
  return CachedPlaylistRepository(
    PlaylistsApi(ref.watch(apiClientProvider)),
    settings.prefs,
    userId: () => settings.session?.user.id,
  );
});

final playlistDetailProvider = FutureProvider.autoDispose.family<PlaylistDetail, String>(
  (ref, id) => ref.watch(playlistRepositoryProvider).get(id),
);

final playlistsControllerProvider = AsyncNotifierProvider<PlaylistsController, List<Playlist>>(PlaylistsController.new);

class PlaylistsController extends AsyncNotifier<List<Playlist>> {
  PlaylistRepository get _repo => ref.read(playlistRepositoryProvider);

  @override
  Future<List<Playlist>> build() async {
    // Device-only mode: server playlists are unavailable, no API call.
    if (ref.watch(authControllerProvider) == null) return const [];
    return _repo.list();
  }

  /// Sends offline edits and refreshes the saved copy (app start / resume).
  Future<void> sync() async {
    if (ref.read(authControllerProvider) == null) return;
    try {
      await _reload();
    } catch (_) {
      // Server unavailable: keep showing what we have.
    }
  }

  Future<void> _reload() async {
    state = AsyncData(await _repo.list());
  }

  Future<Playlist> create(String name) async {
    final p = await _repo.create(name);
    await _reload();
    return p;
  }

  Future<void> rename(String id, String name) async {
    await _repo.rename(id, name);
    ref.invalidate(playlistDetailProvider(id));
    await _reload();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await _reload();
  }

  Future<void> addTracks(String id, List<Track> tracks) async {
    final detail = await _repo.get(id);
    await _repo.setTracks(id, [...detail.tracks, ...tracks]);
    ref.invalidate(playlistDetailProvider(id));
    await _reload();
  }

  /// Replaces the ordered track list (reorder / remove).
  Future<void> setTracks(String id, List<Track> tracks) async {
    await _repo.setTracks(id, tracks);
    ref.invalidate(playlistDetailProvider(id));
    await _reload();
  }
}
