import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/track_tile.dart';
import '../../downloads/ui/offline_status.dart';
import 'player_providers.dart';

Future<void> showQueueSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scroll) => Consumer(builder: (context, ref, _) {
          final snap = ref.watch(playerSnapshotProvider).value;
          final queue = snap?.queue ?? const [];
          final port = ref.read(playerPortProvider);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(context.l10n.queue,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      tooltip: context.l10n.shuffle,
                      onPressed: () => port.setShuffle(!(snap?.shuffle ?? false)),
                      icon: Icon(Icons.shuffle_rounded,
                          color: (snap?.shuffle ?? false) ? QodiTokens.orange : QodiColors.of(context).textMuted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: queue.length,
                  itemBuilder: (_, i) => TrackTile(
                    track: queue[i],
                    highlighted: i == snap?.queuePosition,
                    onTap: () => port.jumpTo(i),
                    trailing: OfflineTrackBadge(queue[i].id),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
