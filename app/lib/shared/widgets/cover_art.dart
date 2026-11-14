import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/core_providers.dart';
import '../../core/theme/tokens.dart';

/// Deterministic palette pick for an id (album/track/playlist).
List<Color> seedColors(String seed) {
  const palettes = [
    [Color(0xFFE8653F), Color(0xFFF2A65A)],
    [Color(0xFF0F2233), Color(0xFF3D5A80)],
    [Color(0xFF5B8E7D), Color(0xFFBCD8C1)],
    [Color(0xFF9C6644), Color(0xFFDDB892)],
    [Color(0xFF6D597A), Color(0xFFE56B6F)],
    [Color(0xFF264653), Color(0xFF2A9D8F)],
    [Color(0xFFD62828), Color(0xFFF77F00)],
    [Color(0xFF3A86FF), Color(0xFF8ECAE6)],
  ];
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palettes[h % palettes.length];
}

/// Square/rounded artwork for a track id with a deterministic gradient
/// fallback when there is no cover (or it fails to load, e.g. offline).
class CoverArt extends ConsumerWidget {
  const CoverArt({
    super.key,
    required this.seed,
    this.trackId,
    this.size,
    this.radius = QodiTokens.radiusM,
    this.circle = false,
    this.icon = Icons.music_note_rounded,
  });

  final String seed;
  final String? trackId;
  final double? size;
  final double radius;
  final bool circle;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = trackId == null ? null : ref.watch(mediaUrlsProvider).cover(trackId!);
    final colors = seedColors(seed);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: LayoutBuilder(
          builder: (context, c) => Icon(icon,
              color: Colors.white.withValues(alpha: 0.85),
              size: (c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 48) * 0.4),
        ),
      ),
    );
    final image = url == null
        ? fallback
        : Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => fallback,
            frameBuilder: (context, child, frame, sync) =>
                frame == null && !sync ? fallback : child,
          );
    final clipped = circle
        ? ClipOval(child: image)
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
    return SizedBox(width: size, height: size, child: clipped);
  }
}
