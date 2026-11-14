import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../device_music/domain/device_track.dart';
import '../../library/domain/entities.dart';
import 'downloads_controller.dart';

/// User-facing copy of the offline indicators (kept together for translation).
abstract final class OfflineStrings {
  static const availableOffline = 'Available offline';
  static const downloaded = 'Downloaded';
  static String someDownloaded(int done, int total) => '$done of $total downloaded';
}

/// A track plays without a connection when it is downloaded or stored on the
/// device. Always false on web (no downloads, no device music).
final trackAvailableOfflineProvider = Provider.family<bool, String>((ref, id) =>
    isDeviceTrackId(id) || ref.watch(downloadsControllerProvider.select((s) => s.isDownloaded(id))));

/// Server track ids per album, from the local library cache (native only).
final _albumTrackIdsProvider = FutureProvider<Map<String, List<String>>>((ref) async {
  // Re-read when downloads change (the cache may have been synced since).
  ref.watch(downloadsControllerProvider.select((s) => s.ids.length));
  final all = await ref.watch(platformServicesProvider).cache.allTracks();
  final byAlbum = <String, List<String>>{};
  for (final t in all) {
    byAlbum.putIfAbsent(t.albumId, () => []).add(t.id);
  }
  return byAlbum;
});

/// Device albums, and server albums whose cached tracks are all downloaded.
final albumAvailableOfflineProvider = Provider.family<bool, String>((ref, albumId) {
  if (albumId.startsWith(deviceAlbumIdPrefix)) return true;
  final downloaded = ref.watch(downloadsControllerProvider.select((s) => s.ids));
  if (downloaded.isEmpty) return false;
  final ids = ref.watch(_albumTrackIdsProvider).value?[albumId];
  return ids != null && ids.isNotEmpty && ids.every(downloaded.contains);
});

/// Offline progress of a collection (album, playlist, artist).
class OfflineSummary {
  const OfflineSummary({required this.available, required this.total, required this.downloading, required this.progress});

  /// Tracks available offline (downloaded or on the device).
  final int available;
  final int total;

  /// Tracks of the collection being downloaded right now.
  final int downloading;

  /// Overall progress 0..1, counting partial downloads.
  final double progress;

  bool get complete => total > 0 && available == total;

  /// "Downloaded", "N of M downloaded", or null when nothing is offline.
  String? get label => complete
      ? OfflineStrings.downloaded
      : available > 0
          ? OfflineStrings.someDownloaded(available, total)
          : null;

  static OfflineSummary of(List<Track> tracks, DownloadsState state) {
    var available = 0, downloading = 0;
    var partial = 0.0;
    for (final t in tracks) {
      if (isDeviceTrackId(t.id) || state.isDownloaded(t.id)) {
        available++;
      } else if (state.isDownloading(t.id)) {
        downloading++;
        partial += state.progress[t.id] ?? 0;
      }
    }
    final total = tracks.length;
    return OfflineSummary(
      available: available,
      total: total,
      downloading: downloading,
      progress: total == 0 ? 0 : (available + partial) / total,
    );
  }
}

/// Small orange circle with a check-download icon.
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: OfflineStrings.availableOffline,
        child: Tooltip(
          message: OfflineStrings.availableOffline,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: QodiTokens.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: size >= 18 ? 1.5 : 1),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.download_done_rounded, color: Colors.white, size: size * 0.66),
          ),
        ),
      );
}

/// [child] (a cover) with an [OfflineBadge] in its bottom-right corner when
/// the track, or the album with [albumId], is available offline.
class OfflineCoverBadge extends ConsumerWidget {
  const OfflineCoverBadge({super.key, this.trackId, this.albumId, required this.child, this.badgeSize = 22, this.inset = 4})
      : assert(trackId != null || albumId != null);

  final String? trackId;
  final String? albumId;
  final Widget child;
  final double badgeSize;
  final double inset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = trackId != null
        ? ref.watch(trackAvailableOfflineProvider(trackId!))
        : ref.watch(albumAvailableOfflineProvider(albumId!));
    if (!offline) return child;
    return Stack(
      children: [
        child,
        Positioned(right: inset, bottom: inset, child: OfflineBadge(size: badgeSize)),
      ],
    );
  }
}

/// Trailing badge for rows that build their own trailing widgets.
class OfflineTrackBadge extends ConsumerWidget {
  const OfflineTrackBadge(this.trackId, {super.key});
  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(trackAvailableOfflineProvider(trackId))
      ? const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: OfflineBadge())
      : const SizedBox.shrink();
}
