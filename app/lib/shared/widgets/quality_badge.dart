import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../features/library/domain/audio_quality.dart';
import '../../features/library/domain/entities.dart';

/// Compact quality label for track rows, e.g. `FLAC · 24/96`. Hi-Res files
/// are tinted orange.
class QualityLabel extends StatelessWidget {
  const QualityLabel({super.key, required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    final hiRes = qualityTier(track) == QualityTier.hiRes;
    final color = hiRes ? QodiTokens.orange : c.textMuted;
    return Container(
      key: ValueKey('quality-${track.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        qualityLabel(track),
        maxLines: 1,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
    );
  }
}

/// Prominent Now Playing badge: a "Hi-Res"/"Lossless" pill (only when the
/// played audio is lossless) next to what is actually being played.
class NowPlayingQualityBadge extends StatelessWidget {
  const NowPlayingQualityBadge({super.key, required this.track, this.transcodedOpusKbps});
  final Track track;

  /// Set when the server transcodes the stream to Opus at this bitrate.
  final int? transcodedOpusKbps;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    final tier = transcodedOpusKbps == null ? qualityTier(track) : QualityTier.lossy;
    final badge = qualityBadgeText(tier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badge != null) ...[
          Container(
            key: const Key('np-quality-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: tier == QualityTier.hiRes ? QodiTokens.orange : Colors.transparent,
              border: Border.all(color: QodiTokens.orange, width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: tier == QualityTier.hiRes ? Colors.white : QodiTokens.orange,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            streamedQualityLabel(track, transcodedOpusKbps: transcodedOpusKbps),
            key: const Key('np-quality'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
