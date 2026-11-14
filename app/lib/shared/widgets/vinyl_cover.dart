import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'cover_art.dart';

/// A vinyl record with concentric grooves. The center label shows the cover
/// (when [trackId] has one) or deterministic colors from [seed]. It rotates
/// while [spinning] and keeps its angle when paused.
class VinylCover extends StatefulWidget {
  const VinylCover({
    super.key,
    required this.seed,
    this.trackId,
    this.size = 120,
    this.spinning = false,
    this.labelFraction = 0.42,
  });

  final String seed;
  final String? trackId;
  final double size;
  final bool spinning;
  final double labelFraction;

  @override
  State<VinylCover> createState() => _VinylCoverState();
}

class _VinylCoverState extends State<VinylCover> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 8));

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _controller.repeat();
  }

  @override
  void didUpdateWidget(VinylCover old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spinning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final label = size * widget.labelFraction;
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: Size.square(size), painter: _VinylPainter()),
            CoverArt(
              seed: widget.seed,
              trackId: widget.trackId,
              size: label,
              circle: true,
            ),
            Container(
              width: size * 0.045,
              height: size * 0.045,
              decoration: const BoxDecoration(color: Color(0xFF111111), shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF141414));
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.006)
      ..color = const Color(0xFF2E2E2E);
    for (var rr = r * 0.95; rr > r * 0.46; rr -= r * 0.045) {
      canvas.drawCircle(c, rr, groove);
    }
    // Sheen
    final sheen = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, sheen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
