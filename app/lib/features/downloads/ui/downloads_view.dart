import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/l10n.dart';
import '../../library/domain/entities.dart';
import '../../library/ui/track_actions.dart';
import 'downloads_controller.dart';

/// Downloaded tracks resolved from the local library cache.
final downloadedTracksProvider = FutureProvider.autoDispose<List<Track>>((ref) async {
  final ids = ref.watch(downloadsControllerProvider.select((s) => s.ids));
  final all = await ref.watch(platformServicesProvider).cache.allTracks();
  return all.where((t) => ids.contains(t.id)).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
});

class DownloadsView extends ConsumerWidget {
  const DownloadsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = QodiColors.of(context);
    final state = ref.watch(downloadsControllerProvider);
    return ref.watch(downloadedTracksProvider).when(
          data: (tracks) => ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              if (state.progress.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(context.l10n.downloadingCount(state.progress.length),
                      style: const TextStyle(color: QodiTokens.orange, fontWeight: FontWeight.w600)),
                ),
              if (tracks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.l10n.noDownloadsYet,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textMuted),
                  ),
                ),
              for (var i = 0; i < tracks.length; i++)
                ConnectedTrackTile(
                  track: tracks[i],
                  queue: tracks,
                  index: i,
                  trailing: IconButton(
                    tooltip: context.l10n.removeDownload,
                    icon: Icon(Icons.delete_outline_rounded, color: c.textMuted),
                    onPressed: () => ref.read(downloadsControllerProvider.notifier).delete(tracks[i].id),
                  ),
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: QodiTokens.orange)),
          error: (e, _) => Center(child: Text(context.l10n.downloadsLoadFailed('$e'))),
        );
  }
}
