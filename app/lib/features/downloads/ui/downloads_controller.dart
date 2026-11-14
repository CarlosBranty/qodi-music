import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/media_urls.dart';
import '../../../core/config/core_providers.dart';
import '../../../core/config/settings_store.dart';
import '../../library/domain/entities.dart';
import '../domain/download_store.dart';

/// Null on web (no offline downloads).
final downloadStoreProvider = Provider<DownloadStore?>((ref) =>
    ref.watch(platformServicesProvider).createDownloads(ref.watch(apiClientProvider)));

class DownloadsState {
  const DownloadsState({this.ids = const {}, this.progress = const {}, this.error});
  final Set<String> ids;
  final Map<String, double> progress;
  final String? error;

  bool isDownloaded(String id) => ids.contains(id);
  bool isDownloading(String id) => progress.containsKey(id);
}

final downloadsControllerProvider =
    NotifierProvider<DownloadsController, DownloadsState>(DownloadsController.new);

class DownloadsController extends Notifier<DownloadsState> {
  DownloadStore? get _store => ref.read(downloadStoreProvider);

  @override
  DownloadsState build() {
    Future.microtask(refresh);
    return const DownloadsState();
  }

  bool get supported => _store != null;

  Future<void> refresh() async {
    final store = _store;
    if (store == null) return;
    final ids = await store.downloadedIds();
    state = DownloadsState(ids: ids, progress: state.progress);
  }

  Future<void> download(Track track) async {
    final store = _store;
    if (store == null || state.isDownloaded(track.id) || state.isDownloading(track.id)) return;
    final url = ref.read(mediaUrlsProvider).stream(track, StreamQuality.original);
    _setProgress(track.id, 0);
    try {
      await store.download(track.id, url, originalExtension(track),
          onProgress: (p) => _setProgress(track.id, p));
      state = DownloadsState(
        ids: {...state.ids, track.id},
        progress: Map.of(state.progress)..remove(track.id),
      );
    } catch (e) {
      state = DownloadsState(
        ids: state.ids,
        progress: Map.of(state.progress)..remove(track.id),
        error: 'Download failed: ${track.title}',
      );
    }
  }

  Future<void> downloadAll(List<Track> tracks) async {
    for (final t in tracks) {
      await download(t);
    }
  }

  Future<void> delete(String trackId) async {
    await _store?.delete(trackId);
    state = DownloadsState(ids: {...state.ids}..remove(trackId), progress: state.progress);
  }

  void _setProgress(String id, double p) {
    state = DownloadsState(ids: state.ids, progress: {...state.progress, id: p});
  }
}
