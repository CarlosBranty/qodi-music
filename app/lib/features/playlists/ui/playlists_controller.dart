import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/core_providers.dart';
import '../../auth/ui/auth_controller.dart';
import '../../library/domain/entities.dart';
import '../data/playlists_api.dart';
import '../domain/playlist.dart';

final playlistRepositoryProvider =
    Provider<PlaylistRepository>((ref) => PlaylistsApi(ref.watch(apiClientProvider)));

final playlistDetailProvider = FutureProvider.autoDispose.family<PlaylistDetail, String>(
    (ref, id) => ref.watch(playlistRepositoryProvider).get(id));

final playlistsControllerProvider =
    AsyncNotifierProvider<PlaylistsController, List<Playlist>>(PlaylistsController.new);

class PlaylistsController extends AsyncNotifier<List<Playlist>> {
  PlaylistRepository get _repo => ref.read(playlistRepositoryProvider);

  @override
  Future<List<Playlist>> build() {
    ref.watch(authControllerProvider);
    return _repo.list();
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
    await _repo.setTracks(id, [...detail.tracks.map((t) => t.id), ...tracks.map((t) => t.id)]);
    ref.invalidate(playlistDetailProvider(id));
    await _reload();
  }

  /// Replaces the ordered track list (reorder / remove).
  Future<void> setTracks(String id, List<Track> tracks) async {
    await _repo.setTracks(id, tracks.map((t) => t.id).toList());
    ref.invalidate(playlistDetailProvider(id));
    await _reload();
  }
}
