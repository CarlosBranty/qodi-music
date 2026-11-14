import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../l10n/l10n.dart';

/// Waveform drawn as vertical bars along an upward arc. The played part is
/// orange with a thicker orange arc line and a round thumb; the rest is light
/// grey. Tap or drag horizontally to seek.
class ArcWaveformSeekbar extends StatefulWidget {
  const ArcWaveformSeekbar({
    super.key,
    required this.peaks,
    required this.progress,
    required this.onSeek,
    this.height = 120,
    this.activeColor,
    this.inactiveColor,
  });

  final List<double> peaks;

  /// 0..1
  final double progress;
  final ValueChanged<double> onSeek;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  State<ArcWaveformSeekbar> createState() => _ArcWaveformSeekbarState();
}

class _ArcWaveformSeekbarState extends State<ArcWaveformSeekbar> {
  double? _drag;

  double _toProgress(double dx, double width) =>
      ((dx - ArcGeometry.pad) / (width - 2 * ArcGeometry.pad)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = QodiColors.of(context);
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final value = (_drag ?? widget.progress).clamp(0.0, 1.0);
      return Semantics(
        slider: true,
        label: context.l10n.seek,
        value: '${(value * 100).round()}%',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => widget.onSeek(_toProgress(d.localPosition.dx, width)),
          onHorizontalDragStart: (d) =>
              setState(() => _drag = _toProgress(d.localPosition.dx, width)),
          onHorizontalDragUpdate: (d) =>
              setState(() => _drag = _toProgress(d.localPosition.dx, width)),
          onHorizontalDragEnd: (_) {
            final v = _drag;
            setState(() => _drag = null);
            if (v != null) widget.onSeek(v);
          },
          onHorizontalDragCancel: () => setState(() => _drag = null),
          child: CustomPaint(
            size: Size(width, widget.height),
            painter: ArcWaveformPainter(
              peaks: widget.peaks,
              progress: value,
              active: widget.activeColor ?? colors.accent,
              inactive: widget.inactiveColor ?? colors.waveRest,
              thumbBorder: colors.cardStrong,
            ),
          ),
        ),
      );
    });
  }
}

/// Shared arc geometry so painting and hit-testing agree.
class ArcGeometry {
  ArcGeometry(Size size) {
    final chord = size.width - 2 * pad;
    maxBar = size.height * 0.38;
    final top = maxBar + 4;
    final sagitta = math.max(8.0, size.height - top - thumbRadius - 4);
    radius = (chord * chord / 4 + sagitta * sagitta) / (2 * sagitta);
    center = Offset(size.width / 2, top + radius);
    halfAngle = math.asin(((chord / 2) / radius).clamp(-1.0, 1.0));
  }

  static const pad = 16.0;
  static const thumbRadius = 9.0;
  late final double maxBar;
  late final double radius;
  late final Offset center;
  late final double halfAngle;

  double angleAt(double t) => -halfAngle + 2 * halfAngle * t;

  Offset pointAt(double angle, [double r = 0]) => center +
      Offset(math.sin(angle), -math.cos(angle)) * (radius + r);
}

class ArcWaveformPainter extends CustomPainter {
  ArcWaveformPainter({
    required this.peaks,
    required this.progress,
    required this.active,
    required this.inactive,
    required this.thumbBorder,
  });

  final List<double> peaks;
  final double progress;
  final Color active;
  final Color inactive;
  final Color thumbBorder;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 2 * ArcGeometry.pad) return;
    final g = ArcGeometry(size);
    final n = peaks.isEmpty ? 1 : peaks.length;
    final barWidth = math.max(1.5, (size.width - 2 * ArcGeometry.pad) / n * 0.55);
    final bar = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    for (var i = 0; i < peaks.length; i++) {
      final t = n == 1 ? 0.5 : i / (n - 1);
      final a = g.angleAt(t);
      final h = 3 + peaks[i].clamp(0.0, 1.0) * (g.maxBar - 6);
      bar.color = t <= progress ? active : inactive;
      canvas.drawLine(g.pointAt(a, -4), g.pointAt(a, -4 - h), bar);
    }

    // Base arc: thin grey, thick orange up to the thumb.
    final rect = Rect.fromCircle(center: g.center, radius: g.radius + 4);
    const start = -math.pi / 2;
    final rest = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = inactive;
    canvas.drawArc(rect, start - g.halfAngle, 2 * g.halfAngle, false, rest);
    final played = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = active;
    canvas.drawArc(rect, start - g.halfAngle, 2 * g.halfAngle * progress, false, played);

    final thumb = g.pointAt(g.angleAt(progress), 4);
    canvas.drawCircle(thumb, ArcGeometry.thumbRadius + 3, Paint()..color = thumbBorder);
    canvas.drawCircle(thumb, ArcGeometry.thumbRadius, Paint()..color = active);
  }

  @override
  bool shouldRepaint(ArcWaveformPainter old) =>
      old.progress != progress ||
      old.peaks != peaks ||
      old.active != active ||
      old.inactive != inactive;
}
