import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../features/library/domain/entities.dart';
import 'cover_art.dart';

/// Favorites-style row: round cover, bold title, grey artist, orange heart.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.onLongPress,
    this.onMore,
    this.favorite,
    this.onFavorite,
    this.leading,
    this.trailing,
    this.highlighted = false,
    this.subtitle,
  });

  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;
  final bool? favorite;
  final VoidCallback? onFavorite;
  final Widget? leading;
  final Widget? trailing;
  final bool highlighted;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    final theme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress ?? onMore,
      borderRadius: BorderRadius.circular(QodiTokens.radiusM),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            leading ??
                CoverArt(
                  seed: track.albumId,
                  trackId: track.hasCover ? track.id : null,
                  size: 52,
                  circle: true,
                ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: highlighted ? QodiTokens.orange : c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle ?? track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall?.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            ?trailing,
            if (favorite != null)
              IconButton(
                tooltip: favorite! ? 'Remove from favorites' : 'Add to favorites',
                onPressed: onFavorite,
                icon: Icon(
                  favorite! ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: QodiTokens.orange,
                ),
              ),
            if (onMore != null)
              IconButton(
                tooltip: 'More',
                onPressed: onMore,
                icon: Icon(Icons.more_vert_rounded, color: c.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
