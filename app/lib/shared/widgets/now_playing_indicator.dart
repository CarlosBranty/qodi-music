import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';

/// Three equalizer bars marking the track that is currently loaded in the
/// player. The bars bounce while [animate] is true and rest when paused.
class NowPlayingIndicator extends StatefulWidget {
  const NowPlayingIndicator({super.key, this.animate = false, this.size = 14, this.color = QodiTokens.orange});

  final bool animate;
  final double size;
  final Color color;

  @override
  State<NowPlayingIndicator> createState() => _NowPlayingIndicatorState();
}

class _NowPlayingIndicatorState extends State<NowPlayingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(NowPlayingIndicator old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) _sync();
  }

  void _sync() {
    if (widget.animate) {
      _ctrl.repeat();
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const rest = [0.45, 0.85, 0.6];
    final s = widget.size;
    return SizedBox.square(
      dimension: s,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: s / 4.5,
                height:
                    s *
                    (widget.animate
                        ? 0.3 + 0.7 * (0.5 + 0.5 * math.sin(2 * math.pi * _ctrl.value + i * 2.1)).abs()
                        : rest[i]),
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(s / 9)),
              ),
          ],
        ),
      ),
    );
  }
}
