import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/core_providers.dart';
import '../../device_music/domain/device_track.dart';
import '../../downloads/ui/downloads_controller.dart';
import '../data/cached_library_repository.dart';
import '../data/library_api.dart';
import '../data/library_sync_service.dart';
import '../domain/entities.dart';
import '../domain/library_repository.dart';

final libraryApiProvider = Provider<LibraryApi>((ref) => LibraryApi(ref.watch(apiClientProvider)));

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) => CachedLibraryRepository(
      ref.watch(libraryApiProvider),
      ref.watch(platformServicesProvider).cache,
    ));

final librarySyncProvider = Provider<LibrarySyncService>((ref) => LibrarySyncService(
      ref.watch(libraryApiProvider),
      ref.watch(platformServicesProvider).cache,
      ref.watch(downloadStoreProvider),
    ));

final searchTracksProvider = FutureProvider.autoDispose.family<List<Track>, String>(
    (ref, q) => ref.watch(libraryRepositoryProvider).tracks(query: q));

final albumsProvider =
    FutureProvider.autoDispose<List<Album>>((ref) => ref.watch(libraryRepositoryProvider).albums());

final artistsProvider =
    FutureProvider.autoDispose<List<Artist>>((ref) => ref.watch(libraryRepositoryProvider).artists());

final albumDetailProvider = FutureProvider.autoDispose.family<AlbumDetail, String>(
    (ref, id) => ref.watch(libraryRepositoryProvider).album(id));

final artistAlbumsProvider = FutureProvider.autoDispose.family<List<Album>, String>(
    (ref, id) => ref.watch(libraryRepositoryProvider).albums(artistId: id));

final artistTracksProvider = FutureProvider.autoDispose.family<List<Track>, String>(
    (ref, id) => ref.watch(libraryRepositoryProvider).tracks(artistId: id));

/// 120 waveform peaks (0..1). Falls back to a flat line when unavailable.
/// Device tracks and device-only mode never ask the server.
final waveformProvider = FutureProvider.autoDispose.family<List<double>, String>((ref, id) async {
  if (isDeviceTrackId(id) || !ref.watch(apiClientProvider).hasSession) {
    return List<double>.filled(120, 0.25);
  }
  try {
    final peaks = await ref.watch(libraryApiProvider).waveform(id);
    if (peaks.isNotEmpty) return peaks;
  } catch (_) {}
  return List<double>.filled(120, 0.25);
});

/// Recently played tracks (local history, most recent first).
final historyProvider = NotifierProvider<HistoryController, List<Track>>(HistoryController.new);

class HistoryController extends Notifier<List<Track>> {
  @override
  List<Track> build() => ref.read(settingsStoreProvider).history;

  Future<void> push(Track t) async {
    state = await ref.read(settingsStoreProvider).pushHistory(t);
  }
}
